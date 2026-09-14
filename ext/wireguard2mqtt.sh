#!/usr/bin/env bash
#
# wireguard2mqtt — WireGuard peer state into Home Assistant over MQTT.
# Called by services/wireguard2mqtt.nix; same shape as blocky-stats2mqtt.sh
# and server-health2mqtt.sh: the host judges its own health (`problems` is
# computed here, not in HA) and every entity registers itself through retained
# MQTT discovery, so HA's config never enumerates the peers.
#
# Modes:
#   state      read `wg show <iface> dump`, publish one retained record per peer
#   discovery  publish the retained HA discovery configs (generated in Nix)
#   purge      delete those discovery configs (empty retained payload)
#
# No local state is kept — MQTT retain is the state store, and rx/tx come from
# WireGuard's own cumulative counters, so there are no deltas to remember. Same
# rule as server-health2mqtt: this box boots off small flash.
set -euo pipefail

MODE="${1:-state}"

IFACE="${WG_IFACE:?WG_IFACE is required}"
TOPIC="${WG_TOPIC:?WG_TOPIC is required}"
BROKER="${WG_BROKER:-localhost}"
PORT="${WG_PORT:-1883}"
MQTT_USER="${WG_MQTT_USER:-}"
MQTT_PASS="${WG_MQTT_PASS:-}"
# pubkey<TAB>name<TAB>alwaysOn(0|1), generated in Nix from the interface's own
# peer list so the names here are the names in configuration.nix.
PEERS_FILE="${WG_PEERS_FILE:?WG_PEERS_FILE is required}"
# Only `alwaysOn` peers are allowed to raise a problem. A phone or laptop being
# disconnected is the normal case and must never alert; the site-to-site link to
# nnas going quiet is a real fault.
HANDSHAKE_MAX_AGE="${WG_HANDSHAKE_MAX_AGE:-900}"

PUB_FAILURES=0

pub() {
  local topic="$1" payload="$2"
  if [[ "${WG_DRY_RUN:-0}" == "1" ]]; then
    printf '%s %s\n' "$topic" "$payload"
    return
  fi
  local args=(-h "$BROKER" -p "$PORT" -q 1 -r -t "$topic" -m "$payload")
  [[ -n "$MQTT_USER" ]] && args+=(-u "$MQTT_USER")
  [[ -n "$MQTT_PASS" ]] && args+=(-P "$MQTT_PASS")
  if ! mosquitto_pub "${args[@]}"; then
    echo "failed to publish ${topic}" >&2
    PUB_FAILURES=$(( PUB_FAILURES + 1 ))
  fi
}

publish_from_file() {
  local file="$1" empty="$2" count=0 topic payload
  while IFS=$'\t' read -r topic payload; do
    [[ -n "$topic" ]] || continue
    if [[ "$empty" == "1" ]]; then
      pub "$topic" ""
    else
      pub "$topic" "$payload"
    fi
    count=$(( count + 1 ))
  done < <(jq -r '.[] | [.topic, (.payload | tojson)] | @tsv' "$file")
  echo "$count"
}

case "$MODE" in
  discovery)
    file="${WG_DISCOVERY_FILE:?WG_DISCOVERY_FILE is required for discovery mode}"
    echo "published $(publish_from_file "$file" 0) discovery configs" >&2
    ;;

  purge)
    # Entities come from *retained* discovery configs, so deleting them in the
    # HA UI alone just brings them back on the next broker reconnect. Clearing
    # the retained config is the only way; `discovery` recreates them.
    file="${WG_DISCOVERY_FILE:?WG_DISCOVERY_FILE is required for purge mode}"
    echo "purged $(publish_from_file "$file" 1) discovery configs" >&2
    echo "now run: systemctl start wireguard2mqtt-discovery" >&2
    ;;

  state)
    now="$(date +%s)"

    # `wg show <iface> dump` is tab-separated, and its FIRST line describes the
    # interface: private-key, public-key, listen-port, fwmark. That leading
    # field is the interface's PRIVATE KEY — it is read here only to be
    # discarded. Nothing from line 1 except the listen port is ever published,
    # and no key material of any kind goes into a payload.
    if ! dump="$(wg show "$IFACE" dump 2>/dev/null)" || [[ -z "$dump" ]]; then
      # The interface is down or absent. Publish a problem on the interface
      # topic and stop: with no dump there is nothing truthful to say about any
      # peer, and overwriting their retained records with zeroes would look like
      # "all peers idle" rather than "we cannot tell".
      #
      # peers_total still comes from the configured list and peers_online is
      # genuinely 0 with the interface down, so neither sensor goes unavailable
      # in the one situation where you most want to look at this device.
      configured="$(grep -c . "$PEERS_FILE" || true)"
      payload="$(jq -n --argjson ts "$now" --arg iface "$IFACE" \
        --argjson peers_total "${configured:-0}" \
        '{ ts: $ts, interface: $iface, up: false,
           peers_total: $peers_total, peers_online: 0, listen_port: null,
           problems: ["wireguard interface \($iface) is down or missing"],
           problem_count: 1 }')"
      pub "$TOPIC" "$payload"
      echo "wireguard: interface ${IFACE} is down or missing" >&2
      [[ "$PUB_FAILURES" -gt 0 ]] && exit 1
      exit 0
    fi

    listen_port="$(awk -F'\t' 'NR == 1 { print $3 }' <<<"$dump")"

    problems=""
    add_problem() { problems+="${1}"$'\n'; }

    peers_total=0
    peers_online=0

    # Index the live dump by public key so the published record is driven by the
    # *configured* peer list, not by whatever wg happens to report. A peer that
    # is configured but missing from the dump still gets a record (offline)
    # instead of silently leaving a stale retained payload in place.
    declare -A live_endpoint live_handshake live_rx live_tx live_allowed
    while IFS=$'\t' read -r pubkey _psk endpoint allowed handshake rx tx _keepalive; do
      [[ -n "$pubkey" ]] || continue
      live_endpoint["$pubkey"]="$endpoint"
      live_handshake["$pubkey"]="$handshake"
      live_rx["$pubkey"]="$rx"
      live_tx["$pubkey"]="$tx"
      live_allowed["$pubkey"]="$allowed"
    done < <(tail -n +2 <<<"$dump")

    while IFS=$'\t' read -r pubkey name always_on; do
      [[ -n "$pubkey" ]] || continue
      peers_total=$(( peers_total + 1 ))

      handshake="${live_handshake[$pubkey]:-}"
      rx="${live_rx[$pubkey]:-0}"
      tx="${live_tx[$pubkey]:-0}"
      endpoint="${live_endpoint[$pubkey]:-}"
      allowed="${live_allowed[$pubkey]:-}"

      # wg prints 0 for "never handshaked" and "(none)" for no endpoint.
      [[ "$endpoint" == "(none)" ]] && endpoint=""

      if [[ -n "$handshake" && "$handshake" != "0" ]]; then
        age=$(( now - handshake ))
        (( age < 0 )) && age=0
        handshake_iso="$(date -u -d "@${handshake}" +%Y-%m-%dT%H:%M:%S+00:00)"
      else
        age=""
        handshake_iso=""
      fi

      # "Online" is the only judgement call here. WireGuard is silent by design:
      # it rekeys roughly every 2 minutes *while traffic flows* and not at all
      # when idle, so a fresh handshake proves the peer is up but a stale one
      # does not prove it is down. The threshold is therefore generous, and only
      # alwaysOn peers turn a stale handshake into a problem.
      online=false
      if [[ -n "$age" ]] && (( age <= HANDSHAKE_MAX_AGE )); then
        online=true
        peers_online=$(( peers_online + 1 ))
      fi

      if [[ "$always_on" == "1" ]]; then
        if [[ -z "$age" ]]; then
          add_problem "peer ${name} has never completed a handshake"
        elif (( age > HANDSHAKE_MAX_AGE )); then
          add_problem "peer ${name} last handshake $(( age / 60 ))m ago"
        fi
      fi

      peer_payload="$(jq -n \
        --argjson ts "$now" \
        --arg name "$name" \
        --argjson online "$online" \
        --arg handshake "$handshake_iso" \
        --arg age "$age" \
        --argjson rx "$rx" \
        --argjson tx "$tx" \
        --arg endpoint "$endpoint" \
        --arg allowed_ips "$allowed" \
        --argjson always_on "$( [[ "$always_on" == "1" ]] && echo true || echo false )" \
        '{
           ts: $ts, name: $name, online: $online,
           handshake: (if $handshake == "" then null else $handshake end),
           handshake_age: (if $age == "" then null else ($age | tonumber) end),
           rx_bytes: $rx, tx_bytes: $tx,
           endpoint: (if $endpoint == "" then null else $endpoint end),
           allowed_ips: $allowed_ips,
           always_on: $always_on
         }')"

      pub "${TOPIC}/peer/${name}" "$peer_payload"
    done < "$PEERS_FILE"

    problems_json="$(jq -R -s 'split("\n") | map(select(length > 0))' <<<"$problems")"
    problem_count="$(jq 'length' <<<"$problems_json")"

    payload="$(jq -n \
      --argjson ts "$now" \
      --arg iface "$IFACE" \
      --argjson listen_port "${listen_port:-0}" \
      --argjson peers_total "$peers_total" \
      --argjson peers_online "$peers_online" \
      --argjson problems "$problems_json" \
      --argjson problem_count "$problem_count" \
      '{
         ts: $ts, interface: $iface, up: true,
         listen_port: $listen_port,
         peers_total: $peers_total, peers_online: $peers_online,
         problems: $problems, problem_count: $problem_count
       }')"

    pub "$TOPIC" "$payload"
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
