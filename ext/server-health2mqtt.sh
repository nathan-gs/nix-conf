#!/usr/bin/env bash
#
# server-health2mqtt — publish host/disk/btrfs health to MQTT for Home Assistant.
#
# Replaces the monthly hw-health-report email with live, retained MQTT state
# under system/network/server/<host>/.
#
# ── Design constraints (nnas is weak; both hosts boot off small flash) ────────
#   * NEVER wake a spinning disk. Every smartctl call passes `-n standby`, so a
#     sleeping disk is skipped, not spun up. SMART data is read from the drive's
#     controller (no platter access) and is therefore free on an already-awake
#     disk.
#   * NEVER write local state. MQTT retain *is* the state store; there is no
#     spool/stamp file, so nothing here dirties the root flash.
#   * The `host` mode touches only /proc, /sys and /run (tmpfs) plus one statfs
#     on / — zero disk IO — so it is cheap enough to run every few minutes.
#     Everything that forks smartctl/btrfs lives in `disks` mode, which runs
#     rarely.
#   * A skipped (standby) disk publishes ONLY to .../standby. The main data
#     topic is left untouched so its retained last-known-good values and their
#     `ts` survive — that `ts` is what HA turns into a "SMART data age" sensor.
#
# Modes:
#   host   — uptime/load/memory/temps/root-fs/failed-units/reboot-required
#   disks  — per-disk SMART + the btrfs filesystem (device errors, usage, scrub)
#
# Configuration comes from the environment; see services/server-health2mqtt.nix.

set -uo pipefail

MODE="${1:?usage: server-health2mqtt <host|disks>}"

HOST="${SH_HOST:-$(cat /proc/sys/kernel/hostname)}"
PREFIX="${SH_TOPIC_PREFIX:?SH_TOPIC_PREFIX is required}"

BROKER="${SH_BROKER:-localhost}"
PORT="${SH_PORT:-1883}"
MQTT_USER="${SH_MQTT_USER:-}"
MQTT_PASS="${SH_MQTT_PASS:-}"

ROOT_DISK="${SH_ROOT_DISK:-}"
DATA_DISKS="${SH_DATA_DISKS:-}"
BTRFS_MOUNT="${SH_BTRFS_MOUNT:-}"
BTRFS_VOLUMES="${SH_BTRFS_VOLUMES:-}"

CPU_TEMP_WARN_C="${SH_CPU_TEMP_WARN_C:-85}"
DISK_TEMP_WARN_C="${SH_DISK_TEMP_WARN_C:-50}"
FS_WARN_PCT="${SH_FS_WARN_PCT:-90}"
SCRUB_MAX_AGE_DAYS="${SH_SCRUB_MAX_AGE_DAYS:-45}"
NVME_WEAR_WARN_PCT="${SH_NVME_WEAR_WARN_PCT:-85}"
# How long `purge` listens for retained discovery configs. Needs to comfortably
# outlast the broker's replay of every retained message under homeassistant/ —
# there are a few thousand of them here, from every integration.
PURGE_WAIT="${SH_PURGE_WAIT:-10}"

# Cumulative counters that never decrease. Alerting on "> 0" would mean a
# permanent alert on any machine carrying an old count, so alert on growth past
# a declared baseline instead. See serverHealth2mqtt.baseline* options.
BASELINE_BTRFS_ERRORS="${SH_BASELINE_BTRFS_ERRORS:-0}"
BASELINE_REALLOCATED="${SH_BASELINE_REALLOCATED:-}"

# Accepted reallocated-sector count for a disk, by serial; 0 if undeclared.
baseline_reallocated() {
  local want="$1" pair
  for pair in $BASELINE_REALLOCATED; do
    if [[ "${pair%%=*}" == "$want" ]]; then
      printf '%s' "${pair#*=}"
      return
    fi
  done
  printf '0'
}

NOW="$(date +%s)"
PUB_FAILURES=0

# ── MQTT ─────────────────────────────────────────────────────────────────────
# Retained: HA must see current state on restart, and a standby disk may not
# publish for days.
pub() {
  local topic="$1" payload="$2"
  # SH_DRY_RUN=1 prints what would be published — handy for testing a new host
  # without touching the broker.
  if [[ "${SH_DRY_RUN:-0}" == "1" ]]; then
    printf '%s %s\n' "$topic" "$payload"
    return
  fi
  local args=(-h "$BROKER" -p "$PORT" -q 1 -r -t "$topic" -m "$payload")
  [[ -n "$MQTT_USER" ]] && args+=(-u "$MQTT_USER")
  [[ -n "$MQTT_PASS" ]] && args+=(-P "$MQTT_PASS")
  if ! mosquitto_pub "${args[@]}"; then
    # Deliberately not fatal: one unreachable topic should not cost us the
    # rest of the run. It does make the unit fail at the end, so an
    # unpublishable host shows up as a failed unit rather than as silence.
    echo "failed to publish ${topic}" >&2
    PUB_FAILURES=$(( PUB_FAILURES + 1 ))
  fi
}

# Turn a newline-separated problem list into a JSON array.
problems_json() {
  jq -R -s 'split("\n") | map(select(length > 0))' <<<"${1:-}"
}

# Is there already a retained payload on this topic?
#
# Used to tell "asleep, but we have known-good data from an earlier run" from
# "asleep and never once read" — the latter needs a placeholder, otherwise the
# disk's entities sit at `unknown` forever on a host whose disks never happen
# to be awake at poll time.
retained_exists() {
  local topic="$1"
  [[ "${SH_DRY_RUN:-0}" == "1" ]] && return 1
  local args=(-h "$BROKER" -p "$PORT" -t "$topic" -C 1 -W 2)
  [[ -n "$MQTT_USER" ]] && args+=(-u "$MQTT_USER")
  [[ -n "$MQTT_PASS" ]] && args+=(-P "$MQTT_PASS")
  local out
  out="$(mosquitto_sub "${args[@]}" 2>/dev/null)" || return 1
  [[ -n "$out" ]]
}

# ── helpers ──────────────────────────────────────────────────────────────────

# Super-I/O chips (nct6793 & friends) report wild values on pins that have no
# thermistor wired to them — this box shows 3892313 °C on its TSI pins and a
# constant 110 °C on floating AUXTINs. Anything outside a range a real machine
# could produce is a disconnected pin, not a reading.
plausible_temp() {
  local v="$1"
  [[ "$v" =~ ^-?[0-9]+$ ]] || return 1
  (( v >= -20 && v <= 150 ))
}

# Highest plausible temperature (°C) across hwmon devices whose name matches $1.
hwmon_temp() {
  local want="$1" best="" n f v
  for n in /sys/class/hwmon/hwmon*/name; do
    [[ -r "$n" ]] || continue
    [[ "$(cat "$n")" == "$want" ]] || continue
    for f in "$(dirname "$n")"/temp*_input; do
      [[ -r "$f" ]] || continue
      v="$(cat "$f" 2>/dev/null)" || continue
      [[ "$v" =~ ^-?[0-9]+$ ]] || continue
      v=$(( v / 1000 ))
      plausible_temp "$v" || continue
      if [[ -z "$best" || "$v" -gt "$best" ]]; then best="$v"; fi
    done
  done
  printf '%s' "$best"
}

cpu_temp() {
  local t
  for name in coretemp k10temp cpu_thermal zenpower; do
    t="$(hwmon_temp "$name")"
    [[ -n "$t" ]] && { printf '%s' "$t"; return; }
  done
  # Fall back to the x86 package thermal zone.
  local z
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r "$z/type" && -r "$z/temp" ]] || continue
    if [[ "$(cat "$z/type")" == "x86_pkg_temp" ]]; then
      printf '%s' "$(( $(cat "$z/temp") / 1000 ))"
      return
    fi
  done
}

# Chipset / platform temperature — the "everything that is not the CPU die"
# reading (PCH on nhtpc, acpitz elsewhere).
#
# Only driver-reported platform sensors are trusted here. Super-I/O chips are
# deliberately NOT candidates: their unconnected pins read as plausible-looking
# 110 °C, which would alert forever. Their values still appear in the `temps`
# attribute map for eyeballing — just never as something we page on.
chipset_temp() {
  local n name t
  for n in /sys/class/hwmon/hwmon*/name; do
    [[ -r "$n" ]] || continue
    name="$(cat "$n")"
    case "$name" in
      pch_*|acpitz)
        t="$(hwmon_temp "$name")"
        [[ -n "$t" ]] && { printf '%s' "$t"; return; }
        ;;
    esac
  done
  local z
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r "$z/type" && -r "$z/temp" ]] || continue
    if [[ "$(cat "$z/type")" == "acpitz" ]]; then
      printf '%s' "$(( $(cat "$z/temp") / 1000 ))"
      return
    fi
  done
}

# Every hwmon temperature and fan, as {"<chip>_<label>": value}. Carried as
# attributes rather than entities: it costs one sysfs read, needs no per-host
# configuration, and keeps board/VRM/fan detail available without minting a
# few dozen entities we would never alert on.
sensor_map() {
  local kind="$1" suffix="$2" divisor="$3"
  local n chip f label key v out=""
  for n in /sys/class/hwmon/hwmon*/name; do
    [[ -r "$n" ]] || continue
    chip="$(cat "$n")"
    for f in "$(dirname "$n")"/${kind}*_${suffix}; do
      [[ -r "$f" ]] || continue
      v="$(cat "$f" 2>/dev/null)" || continue
      [[ "$v" =~ ^-?[0-9]+$ ]] || continue
      [[ "$v" == "0" && "$kind" == "fan" ]] && continue
      if [[ "$kind" == "temp" ]]; then
        plausible_temp "$(( v / divisor ))" || continue
      fi
      label=""
      if [[ -r "${f%_${suffix}}_label" ]]; then
        label="$(tr -c '[:alnum:]' '_' < "${f%_${suffix}}_label" | sed 's/_*$//')"
      fi
      [[ -z "$label" ]] && label="$(basename "${f%_${suffix}}")"
      key="$(tr '[:upper:]' '[:lower:]' <<<"${chip}_${label}")"
      out+="${key}=$(( v / divisor ))"$'\n'
    done
  done
  jq -R -s 'split("\n") | map(select(length > 0) | split("=") | {(.[0]): (.[1] | tonumber)}) | add // {}' <<<"$out"
}

# CPU utilisation needs a delta and we keep no state on disk, so take the
# delta in-process over one second. /proc/stat only — no IO.
cpu_usage() {
  local u1 n1 s1 i1 w1 q1 sq1 st1 u2 n2 s2 i2 w2 q2 sq2 st2
  read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ < /proc/stat
  sleep 1
  read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ < /proc/stat
  awk -v u1="$u1" -v n1="$n1" -v s1="$s1" -v i1="$i1" -v w1="$w1" -v q1="$q1" -v sq1="$sq1" -v st1="${st1:-0}" \
      -v u2="$u2" -v n2="$n2" -v s2="$s2" -v i2="$i2" -v w2="$w2" -v q2="$q2" -v sq2="$sq2" -v st2="${st2:-0}" '
    BEGIN {
      t1 = u1+n1+s1+i1+w1+q1+sq1+st1;
      t2 = u2+n2+s2+i2+w2+q2+sq2+st2;
      dt = t2 - t1;
      if (dt <= 0) { print "0 0"; exit }
      busy = (t2-i2-w2) - (t1-i1-w1);
      printf "%.1f %.1f", busy*100/dt, (w2-w1)*100/dt;
    }'
}

# ── mode: host ───────────────────────────────────────────────────────────────
# /proc + /sys + /run only. No disk is touched.
collect_host() {
  local problems=""

  local uptime_s load1 load5 load15
  uptime_s="$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)"
  read -r load1 load5 load15 _ < /proc/loadavg

  local cpu_count
  cpu_count="$(grep -c '^processor' /proc/cpuinfo)"

  # MemAvailable is the honest "can I allocate this" number; used% derived from
  # it counts reclaimable page cache as free, which is what we want here.
  local mem_total mem_avail mem_used_pct swap_total swap_free swap_used_pct=0
  mem_total="$(awk '/^MemTotal:/{print $2}' /proc/meminfo)"
  mem_avail="$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)"
  mem_used_pct="$(awk -v t="$mem_total" -v a="$mem_avail" 'BEGIN{printf "%.1f", (t-a)*100/t}')"
  swap_total="$(awk '/^SwapTotal:/{print $2}' /proc/meminfo)"
  swap_free="$(awk '/^SwapFree:/{print $2}' /proc/meminfo)"
  if [[ "$swap_total" -gt 0 ]]; then
    swap_used_pct="$(awk -v t="$swap_total" -v f="$swap_free" 'BEGIN{printf "%.1f", (t-f)*100/t}')"
  fi

  local cpu_used_pct cpu_iowait_pct
  read -r cpu_used_pct cpu_iowait_pct < <(cpu_usage)

  local cpu_temp_c nvme_temp_c chipset_temp_c temps fans
  cpu_temp_c="$(cpu_temp)"
  nvme_temp_c="$(hwmon_temp nvme)"
  chipset_temp_c="$(chipset_temp)"
  temps="$(sensor_map temp input 1000)"
  fans="$(sensor_map fan input 1)"

  if [[ -n "$cpu_temp_c" && "$cpu_temp_c" -ge "$CPU_TEMP_WARN_C" ]]; then
    problems+="CPU temperature ${cpu_temp_c}°C"$'\n'
  fi

  # statfs on an already-mounted fs: no device IO.
  local root_used_pct root_free_b
  root_used_pct="$(df --output=pcent / | tail -1 | tr -dc '0-9')"
  root_free_b="$(df --output=avail -B1 / | tail -1 | tr -dc '0-9')"
  if [[ -n "$root_used_pct" && "$root_used_pct" -ge "$FS_WARN_PCT" ]]; then
    problems+="root filesystem ${root_used_pct}% full"$'\n'
  fi

  local failed_names failed_count
  failed_names="$(systemctl list-units --state=failed --no-legend --plain --no-pager 2>/dev/null | awk '{print $1}' | paste -sd, -)"
  failed_count="$(awk -v s="$failed_names" 'BEGIN{if (s == "") print 0; else {n=split(s, a, ","); print n}}')"
  if [[ "$failed_count" -gt 0 ]]; then
    problems+="failed units: ${failed_names}"$'\n'
  fi

  # NixOS idiom: the booted system's kernel/initrd differ from the current
  # system's after a switch that changed them. /run is tmpfs — free to read.
  local reboot_required=false
  if [[ -e /run/booted-system && -e /run/current-system ]]; then
    local b c
    for part in kernel initrd kernel-modules; do
      b="$(readlink -f "/run/booted-system/$part" 2>/dev/null || true)"
      c="$(readlink -f "/run/current-system/$part" 2>/dev/null || true)"
      if [[ -n "$b" && -n "$c" && "$b" != "$c" ]]; then
        reboot_required=true
      fi
    done
  fi
  [[ "$reboot_required" == true ]] && problems+="reboot required (kernel changed)"$'\n'

  jq -n -c \
    --argjson ts "$NOW" \
    --arg host "$HOST" \
    --argjson uptime_s "${uptime_s:-0}" \
    --argjson load1 "${load1:-0}" --argjson load5 "${load5:-0}" --argjson load15 "${load15:-0}" \
    --argjson cpu_count "${cpu_count:-1}" \
    --argjson mem_used_pct "${mem_used_pct:-0}" \
    --argjson mem_available_b "$(( mem_avail * 1024 ))" \
    --argjson swap_used_pct "${swap_used_pct:-0}" \
    --argjson cpu_used_pct "${cpu_used_pct:-0}" \
    --argjson cpu_iowait_pct "${cpu_iowait_pct:-0}" \
    --argjson cpu_temp_c "${cpu_temp_c:-null}" \
    --argjson nvme_temp_c "${nvme_temp_c:-null}" \
    --argjson chipset_temp_c "${chipset_temp_c:-null}" \
    --argjson temps "${temps:-{\}}" \
    --argjson fans "${fans:-{\}}" \
    --argjson root_used_pct "${root_used_pct:-null}" \
    --argjson root_free_b "${root_free_b:-null}" \
    --argjson failed_units "$failed_count" \
    --arg failed_unit_names "$failed_names" \
    --argjson reboot_required "$reboot_required" \
    --argjson problems "$(problems_json "$problems")" \
    '{ts:$ts, host:$host, uptime_s:$uptime_s, load1:$load1, load5:$load5,
      load15:$load15, cpu_count:$cpu_count,
      cpu_used_pct:$cpu_used_pct, cpu_iowait_pct:$cpu_iowait_pct,
      mem_used_pct:$mem_used_pct,
      mem_available_b:$mem_available_b, swap_used_pct:$swap_used_pct,
      cpu_temp_c:$cpu_temp_c, nvme_temp_c:$nvme_temp_c,
      chipset_temp_c:$chipset_temp_c, temps:$temps, fans:$fans,
      root_used_pct:$root_used_pct, root_free_b:$root_free_b,
      failed_units:$failed_units, failed_unit_names:$failed_unit_names,
      reboot_required:$reboot_required,
      problems:$problems, problem_count:($problems|length)}'
}

# ── mode: disks ──────────────────────────────────────────────────────────────

# Short, stable, entity-id-friendly label for a /dev/disk/by-id name:
# the serial after the last underscore, lowercased.
disk_label() {
  local id="${1##*/}"
  printf '%s' "$(tr '[:upper:]' '[:lower:]' <<<"${id##*_}")"
}

# smartctl JSON, with the awkward cases handled:
#  - `-n standby` makes a sleeping disk return immediately without waking it
#  - some devices (SATA DOMs, USB bridges) need an explicit `-d sat` to answer
smart_json() {
  local dev="$1" out status
  out="$(smartctl -j -H -A -i -n standby "$dev" 2>/dev/null)"

  if [[ -n "$out" ]]; then
    status="$(jq -r '.smartctl.exit_status // 0' <<<"$out" 2>/dev/null || echo 0)"
    # bit1 (2) means either "asleep" (then power_mode is set, and we must not
    # retry — a retry with an explicit -d could wake it) or "could not open".
    if (( status & 2 )) && [[ "$(jq -r '.power_mode.name // ""' <<<"$out")" != "" ]]; then
      printf '%s' "$out"
      return
    fi
    # Anything that answered with a SMART status is good enough.
    if [[ "$(jq -r 'has("smart_status")' <<<"$out")" == "true" ]]; then
      printf '%s' "$out"
      return
    fi
  fi

  # Nothing usable: some devices (SATA DOMs, USB bridges) only answer when the
  # transport is named explicitly.
  local retry
  retry="$(smartctl -j -H -A -i -n standby -d sat "$dev" 2>/dev/null)"
  if [[ -n "$retry" ]] && [[ "$(jq -r 'has("smart_status") or (.power_mode != null)' <<<"$retry")" == "true" ]]; then
    printf '%s' "$retry"
    return
  fi
  printf '%s' "${out:-}"
}

collect_disk() {
  local dev="$1" role="$2"
  local label topic out
  label="$(disk_label "$dev")"
  topic="${PREFIX}/disk/${label}"

  out="$(smart_json "$dev")"

  if [[ -z "$out" ]]; then
    pub "${topic}/standby" 'OFF'
    pub "$topic" "$(jq -n -c --argjson ts "$NOW" --arg id "$dev" --arg label "$label" --arg role "$role" \
      '{ts:$ts, smart_ts:null, standby:false, id:$id, label:$label, role:$role,
        available:false, error:"smartctl returned no output",
        temperature_c:null, power_on_hours:null, wear_pct:null, smart_ok:null,
        problems:["SMART unavailable"], problem_count:1}')"
    return
  fi

  local power_mode
  power_mode="$(jq -r '.power_mode.name // ""' <<<"$out")"
  if [[ "$power_mode" == "STANDBY" || "$power_mode" == "SLEEP" ]]; then
    # Asleep. Do NOT wake it and do NOT overwrite the retained data topic —
    # its last-known-good values and `smart_ts` stay put.
    pub "${topic}/standby" 'ON'
    # ...unless we have never read this disk at all, in which case publish a
    # placeholder. A sleeping disk has no *known* problems, so problem_count
    # is 0 (reads "OK") rather than leaving the entity at `unknown`; the
    # genuinely unknown values stay null and their entities unavailable.
    if ! retained_exists "$topic"; then
      pub "$topic" "$(jq -n -c --argjson ts "$NOW" --arg id "$dev" \
        --arg label "$label" --arg role "$role" \
        '{ts:$ts, smart_ts:null, id:$id, label:$label, role:$role,
          available:false, standby:true, error:null,
          temperature_c:null, power_on_hours:null, wear_pct:null,
          smart_ok:null, problems:[], problem_count:0}')"
    fi
    return
  fi
  pub "${topic}/standby" 'OFF'

  # Did smartctl actually manage to talk to the device?
  local msg
  msg="$(jq -r '[.smartctl.messages[]?.string] | join("; ")' <<<"$out")"
  if [[ "$(jq -r 'has("smart_status")' <<<"$out")" != "true" ]]; then
    pub "$topic" "$(jq -n -c --argjson ts "$NOW" --arg id "$dev" --arg label "$label" \
      --arg role "$role" --arg err "${msg:-no SMART data}" \
      '{ts:$ts, smart_ts:null, standby:false, id:$id, label:$label, role:$role,
        available:false, error:$err,
        temperature_c:null, power_on_hours:null, wear_pct:null, smart_ok:null,
        problems:["SMART unavailable: \($err)"], problem_count:1}')"
    return
  fi

  local record
  record="$(jq -c \
    --argjson ts "$NOW" --arg id "$dev" --arg label "$label" --arg role "$role" '
    def attr($n): (.ata_smart_attributes.table // []) | map(select(.name == $n)) | .[0].raw.value;
    {
      ts: $ts, smart_ts: $ts, standby: false,
      id: $id, label: $label, role: $role, available: true, error: null,
      model: (.model_name // null),
      serial: (.serial_number // null),
      protocol: (.device.protocol // null),
      rotation_rate: (.rotation_rate // null),
      capacity_b: (.user_capacity.bytes // .nvme_total_capacity // null),
      smart_ok: (.smart_status.passed // null),
      temperature_c: (.temperature.current // .nvme_smart_health_information_log.temperature // null),
      power_on_hours: (.power_on_time.hours // .nvme_smart_health_information_log.power_on_hours // null),
      power_cycles: (.power_cycle_count // .nvme_smart_health_information_log.power_cycles // null),
      reallocated: (attr("Reallocated_Sector_Ct") // attr("Reallocated_Event_Count")),
      pending: attr("Current_Pending_Sector"),
      offline_uncorrectable: attr("Offline_Uncorrectable"),
      udma_crc_errors: attr("UDMA_CRC_Error_Count"),
      wear_pct: (.nvme_smart_health_information_log.percentage_used
                 // (attr("Percent_Lifetime_Remain") | if . == null then null else 100 - . end)),
      available_spare_pct: (.nvme_smart_health_information_log.available_spare // null),
      media_errors: (.nvme_smart_health_information_log.media_errors // null),
      critical_warning: (.nvme_smart_health_information_log.critical_warning // null)
    }' <<<"$out")"

  # Thresholds live here rather than in HA so each host judges itself — nnas
  # keeps alerting even when it cannot reach the broker's HA instance.
  local problems=""
  local v
  v="$(jq -r '.smart_ok' <<<"$record")"
  [[ "$v" == "false" ]] && problems+="SMART overall health: FAILING"$'\n'

  # Reallocated sectors are cumulative: alert on growth past the accepted
  # count, not on the count being non-zero. A drive that reallocated a handful
  # of sectors years ago and has been stable since is not news; the same drive
  # gaining one more is.
  local realloc realloc_base
  realloc="$(jq -r '.reallocated // 0' <<<"$record")"
  realloc="${realloc%.*}"
  realloc_base="$(baseline_reallocated "$label")"
  if [[ "$realloc" -gt "$realloc_base" ]] 2>/dev/null; then
    if [[ "$realloc_base" -gt 0 ]]; then
      problems+="reallocated sectors: ${realloc} (was ${realloc_base})"$'\n'
    else
      problems+="reallocated sectors: ${realloc}"$'\n'
    fi
  fi

  # These are not "wear that happened once" — any non-zero value is current.
  for field in pending offline_uncorrectable media_errors; do
    v="$(jq -r --arg f "$field" '.[$f] // 0' <<<"$record")"
    if [[ "${v%.*}" -gt 0 ]] 2>/dev/null; then
      problems+="${field//_/ }: ${v%.*}"$'\n'
    fi
  done

  v="$(jq -r '.critical_warning // 0' <<<"$record")"
  [[ "${v%.*}" -gt 0 ]] 2>/dev/null && problems+="NVMe critical warning: ${v%.*}"$'\n'

  v="$(jq -r '.temperature_c // 0' <<<"$record")"
  if [[ "${v%.*}" -ge "$DISK_TEMP_WARN_C" ]] 2>/dev/null; then
    problems+="temperature ${v%.*}°C"$'\n'
  fi

  v="$(jq -r '.wear_pct // 0' <<<"$record")"
  if [[ "${v%.*}" -ge "$NVME_WEAR_WARN_PCT" ]] 2>/dev/null; then
    problems+="flash wear ${v%.*}%"$'\n'
  fi

  pub "$topic" "$(jq -c --argjson problems "$(problems_json "$problems")" \
    '. + {problems:$problems, problem_count:($problems|length)}' <<<"$record")"
}

# All btrfs volumes here are subvolumes of ONE multi-device filesystem, so
# device stats / usage / scrub are filesystem-wide, not per-volume. Publish one
# record and list which subvolume mountpoints are actually mounted.
#
# Every command below reads in-kernel counters or /var/lib/btrfs scrub status —
# none of them touch the platters, so this is safe against sleeping disks.
collect_btrfs() {
  [[ -n "$BTRFS_MOUNT" ]] || return 0
  local topic="${PREFIX}/btrfs"
  local problems=""

  local mounted_vols="" missing_vols=""
  for vol in $BTRFS_VOLUMES; do
    if mountpoint -q "/media/${vol}" 2>/dev/null; then
      mounted_vols+="${vol},"
    else
      missing_vols+="${vol},"
      problems+="/media/${vol} not mounted"$'\n'
    fi
  done
  mounted_vols="${mounted_vols%,}"
  missing_vols="${missing_vols%,}"

  if ! mountpoint -q "$BTRFS_MOUNT" 2>/dev/null; then
    pub "$topic" "$(jq -n -c --argjson ts "$NOW" --arg missing "$missing_vols" \
      --argjson problems "$(problems_json "$problems")" \
      '{ts:$ts, mounted:false, volumes_mounted:"", volumes_missing:$missing,
        problems:$problems, problem_count:($problems|length)}')"
    return
  fi

  # Per-device error counters, summed per counter across devices.
  local stats err_write=0 err_read=0 err_flush=0 err_corruption=0 err_generation=0
  stats="$(btrfs device stats "$BTRFS_MOUNT" 2>/dev/null)"
  err_write="$(awk '/write_io_errs/{s+=$2} END{print s+0}' <<<"$stats")"
  err_read="$(awk '/read_io_errs/{s+=$2} END{print s+0}' <<<"$stats")"
  err_flush="$(awk '/flush_io_errs/{s+=$2} END{print s+0}' <<<"$stats")"
  err_corruption="$(awk '/corruption_errs/{s+=$2} END{print s+0}' <<<"$stats")"
  err_generation="$(awk '/generation_errs/{s+=$2} END{print s+0}' <<<"$stats")"
  local err_total=$(( err_write + err_read + err_flush + err_corruption + err_generation ))
  # Cumulative since the last `btrfs device stats -z`, so compare against the
  # accepted count rather than zero.
  if [[ "$err_total" -gt "$BASELINE_BTRFS_ERRORS" ]]; then
    if [[ "$BASELINE_BTRFS_ERRORS" -gt 0 ]]; then
      problems+="btrfs device errors: ${err_total} (was ${BASELINE_BTRFS_ERRORS}) write=${err_write} read=${err_read} flush=${err_flush} corruption=${err_corruption} generation=${err_generation}"$'\n'
    else
      problems+="btrfs device errors: write=${err_write} read=${err_read} flush=${err_flush} corruption=${err_corruption} generation=${err_generation}"$'\n'
    fi
  fi

  # Devices that dropped out of the array — the failure mode behind the
  # "volume did not mount at boot" alert in disks.nix.
  local usage device_size used free_est devices_missing
  usage="$(btrfs filesystem usage --raw "$BTRFS_MOUNT" 2>/dev/null)"
  device_size="$(awk '/Device size:/{print $3+0}' <<<"$usage")"
  used="$(awk '/^ *Used:/{print $2+0}' <<<"$usage")"
  free_est="$(awk '/Free \(estimated\):/{print $3+0}' <<<"$usage")"
  devices_missing="$(awk '/Device missing:/{print $3+0}' <<<"$usage")"
  [[ "${devices_missing:-0}" -gt 0 ]] && problems+="btrfs device missing: ${devices_missing}"$'\n'

  local used_pct=0
  if [[ "${device_size:-0}" -gt 0 ]]; then
    used_pct="$(awk -v u="$used" -v t="$device_size" 'BEGIN{printf "%.1f", u*100/t}')"
    if [[ "${used_pct%.*}" -ge "$FS_WARN_PCT" ]]; then
      problems+="btrfs ${used_pct}% full"$'\n'
    fi
  fi

  # Scrub state comes from /var/lib/btrfs/*.status — a read, and no device IO.
  local scrub scrub_status scrub_started scrub_started_ts scrub_errors scrub_age_days
  scrub="$(btrfs scrub status "$BTRFS_MOUNT" 2>/dev/null)"
  scrub_status="$(awk -F': *' '/^Status:/{print $2}' <<<"$scrub")"
  scrub_started="$(awk -F'Scrub started: *' '/Scrub started:/{print $2}' <<<"$scrub")"
  if [[ -n "$scrub_started" ]]; then
    scrub_started_ts="$(date -d "$scrub_started" +%s 2>/dev/null || echo "")"
  fi
  if [[ -n "${scrub_started_ts:-}" ]]; then
    scrub_age_days="$(awk -v n="$NOW" -v s="$scrub_started_ts" 'BEGIN{printf "%.1f", (n-s)/86400}')"
    if [[ "${scrub_age_days%.*}" -gt "$SCRUB_MAX_AGE_DAYS" ]]; then
      problems+="last btrfs scrub ${scrub_age_days} days ago"$'\n'
    fi
  fi
  if grep -q 'Error summary:' <<<"$scrub" && ! grep -q 'no errors found' <<<"$scrub"; then
    scrub_errors=1
    problems+="btrfs scrub reported errors: $(awk -F'Error summary: *' '/Error summary:/{print $2}' <<<"$scrub")"$'\n'
  else
    scrub_errors=0
  fi

  pub "$topic" "$(jq -n -c \
    --argjson ts "$NOW" \
    --arg mounted_vols "$mounted_vols" --arg missing_vols "$missing_vols" \
    --argjson device_size "${device_size:-0}" --argjson used "${used:-0}" \
    --argjson free_est "${free_est:-0}" --argjson used_pct "${used_pct:-0}" \
    --argjson devices_missing "${devices_missing:-0}" \
    --argjson err_write "$err_write" --argjson err_read "$err_read" \
    --argjson err_flush "$err_flush" --argjson err_corruption "$err_corruption" \
    --argjson err_generation "$err_generation" --argjson err_total "$err_total" \
    --arg scrub_status "${scrub_status:-unknown}" \
    --argjson scrub_started_ts "${scrub_started_ts:-null}" \
    --argjson scrub_age_days "${scrub_age_days:-null}" \
    --argjson scrub_errors "$scrub_errors" \
    --argjson problems "$(problems_json "$problems")" \
    '{ts:$ts, mounted:true, volumes_mounted:$mounted_vols, volumes_missing:$missing_vols,
      device_size_b:$device_size, used_b:$used, free_b:$free_est, used_pct:$used_pct,
      devices_missing:$devices_missing,
      err_write:$err_write, err_read:$err_read, err_flush:$err_flush,
      err_corruption:$err_corruption, err_generation:$err_generation, err_total:$err_total,
      scrub_status:$scrub_status, scrub_started_ts:$scrub_started_ts,
      scrub_age_days:$scrub_age_days, scrub_errors:$scrub_errors,
      problems:$problems, problem_count:($problems|length)}')"
}

case "$MODE" in
  purge)
    # Remove our Home Assistant discovery configs by publishing an empty
    # retained payload to each, which makes HA drop the entities and their
    # registry entries. Run `discovery` afterwards to recreate them.
    #
    # Two uses:
    #   * Migration, when the generated entity_id changes — HA only honours
    #     default_entity_id when an entity is *created*, so a rename needs the
    #     old entity gone first.
    #   * Cleanup after a disk is replaced: the departed disk's retained
    #     topics would otherwise keep its entities alive forever.
    #
    # Discovery topics only. State topics keep their retained payloads on
    # purpose, so recreated entities repopulate immediately instead of sitting
    # unknown until the next slow-tier run (which, for a sleeping disk, could
    # be days).
    #
    # Enumerates what is actually retained on the broker rather than reading
    # the generated file, so topics for disks this host no longer has are
    # caught too. The prefix match is strict: other integrations publish under
    # homeassistant/ as well and must not be touched.
    # -F '%t' prints the topic and nothing else. Do NOT use -v here: it prints
    # "topic payload", and other integrations on this broker publish
    # pretty-printed JSON, so a payload's later lines get read as topics.
    sub_args=(-h "$BROKER" -p "$PORT" -t 'homeassistant/+/+/config' -F '%t' -W "$PURGE_WAIT")
    [[ -n "$MQTT_USER" ]] && sub_args+=(-u "$MQTT_USER")
    [[ -n "$MQTT_PASS" ]] && sub_args+=(-P "$MQTT_PASS")

    # Scoped to THIS host. It used to match every system_network_server_*
    # object id, which meant running purge on one machine also deleted the
    # other machine's discovery configs — and since `discovery` only ever
    # republishes the local host's, the other host's entities stayed gone until
    # it happened to re-run discovery itself. A host may only remove its own.
    purge_prefix="system_network_server_$(tr '[:upper:]' '[:lower:]' <<<"${HOST//-/_}")_"

    purged=0
    while read -r topic; do
      [[ -n "$topic" ]] || continue
      # homeassistant/<component>/<object_id>/config
      object_id="$(cut -d/ -f3 <<<"$topic")"
      case "$object_id" in
        "$purge_prefix"*) ;;
        *) continue ;;
      esac
      echo "purging ${topic}" >&2
      pub "$topic" ""
      purged=$(( purged + 1 ))
    done < <(mosquitto_sub "${sub_args[@]}" 2>/dev/null || true)

    echo "purged ${purged} discovery configs matching ${purge_prefix}" >&2
    echo "now run: systemctl start server-health2mqtt-discovery" >&2
    ;;
  discovery)
    # Retained discovery configs, generated by the Nix module from *this*
    # host's disk list — so a host registers its own entities and HA never
    # needs an inventory of the other machines.
    file="${SH_DISCOVERY_FILE:?SH_DISCOVERY_FILE is required for discovery mode}"
    count=0
    while IFS=$'\t' read -r topic payload; do
      [[ -n "$topic" ]] || continue
      pub "$topic" "$payload"
      count=$(( count + 1 ))
    done < <(jq -r '.[] | [.topic, (.payload | tojson)] | @tsv' "$file")
    echo "published ${count} discovery configs" >&2
    ;;
  host)
    pub "${PREFIX}/host" "$(collect_host)"
    ;;
  disks)
    [[ -n "$ROOT_DISK" ]] && collect_disk "$ROOT_DISK" root
    for d in $DATA_DISKS; do
      collect_disk "$d" data
    done
    collect_btrfs
    ;;
  *)
    echo "unknown mode: $MODE" >&2
    exit 1
    ;;
esac

if [[ "$PUB_FAILURES" -gt 0 ]]; then
  echo "${PUB_FAILURES} publish failure(s)" >&2
  exit 1
fi
