#!/usr/bin/env bash
#
# blocky-stats2mqtt — blocky's Prometheus metrics endpoint into Home Assistant
# over MQTT. Called by services/blocky.nix; see the comments there for why the
# metrics endpoint is the source rather than blocky's query log.
#
# Modes:
#   stats      read the metrics endpoint, publish one retained JSON record
#   discovery  publish the retained HA discovery configs (generated in Nix)
#   purge      delete those discovery configs (empty retained payload)
#
# Everything is configured through BS_* environment variables so the Nix module
# stays the single source of truth for topics, thresholds and credentials.
set -euo pipefail

MODE="${1:-stats}"

METRICS_URL="${BS_METRICS_URL:?BS_METRICS_URL is required}"
TOPIC="${BS_TOPIC:?BS_TOPIC is required}"
BROKER="${BS_BROKER:-localhost}"
PORT="${BS_PORT:-1883}"
MQTT_USER="${BS_MQTT_USER:-}"
MQTT_PASS="${BS_MQTT_PASS:-}"
STATE="${BS_STATE:-/var/lib/blocky-stats/state}"
LIST_MAX_AGE_HOURS="${BS_LIST_MAX_AGE_HOURS:-48}"

PUB_FAILURES=0

# Retained, like every other publisher here: HA has to see current state on
# restart, and this only runs hourly so an unretained record would leave the
# entities unknown for up to an hour after every HA restart.
pub() {
  local topic="$1" payload="$2"
  if [[ "${BS_DRY_RUN:-0}" == "1" ]]; then
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
    file="${BS_DISCOVERY_FILE:?BS_DISCOVERY_FILE is required for discovery mode}"
    echo "published $(publish_from_file "$file" 0) discovery configs" >&2
    ;;

  purge)
    # Entities come from *retained* discovery configs, so deleting them in the
    # HA UI alone just brings them back on the next broker reconnect. Clearing
    # the retained config is the only way; `discovery` recreates them.
    file="${BS_DISCOVERY_FILE:?BS_DISCOVERY_FILE is required for purge mode}"
    echo "purged $(publish_from_file "$file" 1) discovery configs" >&2
    echo "now run: systemctl start blocky-stats2mqtt-discovery" >&2
    ;;

  stats)
    metrics="$(curl -sf --max-time 10 "$METRICS_URL")"
    [[ -n "$metrics" ]] || { echo "no metrics from ${METRICS_URL}" >&2; exit 1; }

    # Counter values are printed in Go's %g, so anything past a million arrives
    # as "1.602509e+06". awk reads that natively; a `grep -oE '[0-9]+$'` (what
    # the old journal-only version used) silently returns "06" instead — which
    # is why every sum here goes through awk.
    sum_metric() {
      awk -v m="$1" '
        $1 == m || index($1, m "{") == 1 { s += $NF }
        END { printf "%.0f", s + 0 }
      ' <<<"$metrics"
    }

    # Sum blocky_response_total across every series whose response_type matches.
    sum_response() {
      awk -v t="$1" '
        index($1, "blocky_response_total{") == 1 && index($0, "response_type=\"" t "\"") { s += $NF }
        END { printf "%.0f", s + 0 }
      ' <<<"$metrics"
    }

    queries_total="$(sum_metric blocky_response_total)"
    cached_total="$(sum_response CACHED)"
    blocked_total="$(sum_response BLOCKED)"
    # Everything that was neither served from cache nor blocked: RESOLVED plus
    # CUSTOMDNS and any response_type a future blocky adds. Deriving it keeps
    # the three published counts summing to the total by construction.
    resolved_total=$(( queries_total - cached_total - blocked_total ))
    (( resolved_total < 0 )) && resolved_total=0

    errors_total="$(sum_metric blocky_error_total)"
    failed_downloads_total="$(sum_metric blocky_failed_downloads_total)"

    cache_entries="$(sum_metric blocky_cache_entries)"
    prefetch_entries="$(sum_metric blocky_prefetch_domain_name_cache_entries)"
    denylist_entries="$(sum_metric blocky_denylist_cache_entries)"
    allowlist_entries="$(sum_metric blocky_allowlist_cache_entries)"
    blocking_enabled="$(sum_metric blocky_blocking_enabled)"

    version="$(awk '
      index($1, "blocky_build_info{") == 1 {
        if (match($0, /version="[^"]*"/)) {
          v = substr($0, RSTART + 9, RLENGTH - 10)
          print v
        }
        exit
      }' <<<"$metrics")"

    refresh_epoch="$(sum_metric blocky_last_list_group_refresh_timestamp_seconds)"

    # ── deltas ───────────────────────────────────────────────────────────────
    # blocky's counters are cumulative and reset when it restarts. HA could
    # derive the per-hour numbers itself from total_increasing sensors, but the
    # hourly deltas are also what the journal line reports and what the problem
    # check needs (a *new* failed download, not the count since boot), so they
    # are computed here against the previous run.
    # -1, not 0: a missing previous value means "no baseline yet", either
    # because this is the first ever run or because the state file predates the
    # key (prev_errors/prev_failed were added with the MQTT publisher). Starting
    # from 0 would charge blocky's entire lifetime count to this one hour — and
    # for failed downloads that is a spurious problem alert on first run.
    prev_cached=-1; prev_blocked=-1; prev_uncached=-1
    prev_errors=-1; prev_failed=-1
    # shellcheck disable=SC1090
    [[ -f "$STATE" ]] && source "$STATE"

    delta() {
      # Separate statements on purpose: `local a=… d=$((a-…))` expands every
      # word before `local` assigns any of them, so `a` is still unset there.
      local now="$1" prev="$2"
      if (( prev < 0 )); then
        printf '0'
        return
      fi
      local d=$(( now - prev ))
      # A negative delta means blocky restarted and its counters went back to
      # zero. Report 0 for that one run rather than a nonsense negative number.
      (( d < 0 )) && d=0
      printf '%d' "$d"
    }

    d_cached="$(delta "$cached_total" "$prev_cached")"
    d_blocked="$(delta "$blocked_total" "$prev_blocked")"
    d_resolved="$(delta "$resolved_total" "$prev_uncached")"
    d_errors="$(delta "$errors_total" "$prev_errors")"
    d_failed="$(delta "$failed_downloads_total" "$prev_failed")"
    d_queries=$(( d_cached + d_blocked + d_resolved ))

    pct() {
      awk -v n="$1" -v d="$2" 'BEGIN { if (d <= 0) print 0; else printf "%.1f", (n / d) * 100 }'
    }
    blocked_pct="$(pct "$d_blocked" "$d_queries")"
    cache_hit_pct="$(pct "$d_cached" "$d_queries")"

    # ── problems ─────────────────────────────────────────────────────────────
    # Judged here rather than in HA, same as server-health2mqtt: the host that
    # owns the service decides whether it is healthy, HA only routes the list.
    problems=""
    add_problem() { problems+="${1}"$'\n'; }

    (( blocking_enabled == 1 )) || add_problem "blocking is disabled"

    if (( refresh_epoch > 0 )); then
      refresh_iso="$(date -u -d "@${refresh_epoch}" +%Y-%m-%dT%H:%M:%S+00:00)"
      age_hours=$(( ( $(date +%s) - refresh_epoch ) / 3600 ))
      if (( age_hours > LIST_MAX_AGE_HOURS )); then
        add_problem "blocklists last refreshed ${age_hours}h ago"
      fi
    else
      refresh_iso=""
      age_hours=0
      add_problem "blocklists have never been refreshed"
    fi

    # Cumulative failure counts are useless for alerting (one bad list fetch
    # months ago would pin the sensor on forever), so alert on growth in the
    # last run only — the same reasoning as the reallocated-sector baselines.
    (( d_failed > 0 )) && add_problem "${d_failed} blocklist download(s) failed"

    problems_json="$(jq -R -s 'split("\n") | map(select(length > 0))' <<<"$problems")"
    problem_count="$(jq 'length' <<<"$problems_json")"

    payload="$(jq -n \
      --argjson ts "$(date +%s)" \
      --arg version "$version" \
      --argjson queries "$d_queries" \
      --argjson cached "$d_cached" \
      --argjson blocked "$d_blocked" \
      --argjson resolved "$d_resolved" \
      --argjson errors "$d_errors" \
      --argjson failed_downloads "$d_failed" \
      --argjson blocked_pct "$blocked_pct" \
      --argjson cache_hit_pct "$cache_hit_pct" \
      --argjson queries_total "$queries_total" \
      --argjson cached_total "$cached_total" \
      --argjson blocked_total "$blocked_total" \
      --argjson resolved_total "$resolved_total" \
      --argjson cache_entries "$cache_entries" \
      --argjson prefetch_entries "$prefetch_entries" \
      --argjson denylist_entries "$denylist_entries" \
      --argjson allowlist_entries "$allowlist_entries" \
      --argjson blocking_enabled "$blocking_enabled" \
      --arg list_refreshed "$refresh_iso" \
      --argjson list_age_hours "$age_hours" \
      --argjson problems "$problems_json" \
      --argjson problem_count "$problem_count" \
      '{
         ts: $ts, version: $version,
         queries: $queries, cached: $cached, blocked: $blocked,
         resolved: $resolved, errors: $errors,
         failed_downloads: $failed_downloads,
         blocked_pct: $blocked_pct, cache_hit_pct: $cache_hit_pct,
         queries_total: $queries_total, cached_total: $cached_total,
         blocked_total: $blocked_total, resolved_total: $resolved_total,
         cache_entries: $cache_entries, prefetch_entries: $prefetch_entries,
         denylist_entries: $denylist_entries, allowlist_entries: $allowlist_entries,
         blocking_enabled: ($blocking_enabled == 1),
         list_refreshed: (if $list_refreshed == "" then null else $list_refreshed end),
         list_age_hours: $list_age_hours,
         problems: $problems, problem_count: $problem_count
       }')"

    pub "$TOPIC" "$payload"

    # Kept from the journal-only version: one line an hour is nothing on the
    # root flash, and it is the only record left if the broker is unreachable.
    echo "blocky query stats (last hour): cached=${d_cached} uncached=${d_resolved} blocked=${d_blocked}"

    if [[ "${BS_DRY_RUN:-0}" != "1" ]]; then
      mkdir -p "$(dirname "$STATE")"
      # prev_uncached keeps its old name so an existing state file from the
      # journal-only version carries over instead of reporting one bogus hour.
      printf 'prev_cached=%s\nprev_blocked=%s\nprev_uncached=%s\nprev_errors=%s\nprev_failed=%s\n' \
        "$cached_total" "$blocked_total" "$resolved_total" \
        "$errors_total" "$failed_downloads_total" > "$STATE"
    fi
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
