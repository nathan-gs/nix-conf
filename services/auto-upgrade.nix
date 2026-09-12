{ config, pkgs, lib, ... }:

let
  inherit (lib) mkOption mkIf mkEnableOption types;

  cfg = config.autoUpgrade;
  hc = cfg.healthCheck;
  flakeDir = "/etc/nixos/nix-conf";
  secretsDir = "/etc/nixos/secrets";
  hostname = config.networking.hostName;

  # Repo sync (leader → followers over WireGuard) reuses the nhtpc-backup
  # key already authorized on nnas for media-rsync.
  hasRemotes = cfg.syncRemotes != [ ];
  stateDir = "/var/lib/nixos-auto-upgrade";
  identityFile = "${stateDir}/id_ed25519";
  knownHostsFile = "${stateDir}/known_hosts";

  identitySource = pkgs.writeText "auto-upgrade-id_ed25519" config.secrets.ssh.nhtpc-backup.private;
  knownHostsSource = pkgs.writeText "auto-upgrade-known_hosts" ''
    nnas.wg ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuzacgoV7F8Ep4qwnovJZIDOoSea2mrghb7E2LNWFJz
    10.73.221.2 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuzacgoV7F8Ep4qwnovJZIDOoSea2mrghb7E2LNWFJz
  '';

  sshOpts = lib.concatStringsSep " " [
    "-i ${identityFile}"
    "-o IdentitiesOnly=yes"
    "-o UserKnownHostsFile=${knownHostsFile}"
    "-o StrictHostKeyChecking=yes"
    "-o BatchMode=yes"
    "-o ConnectTimeout=30"
  ];

  remoteFlakeAttrs = map (r: r.flakeAttr) cfg.syncRemotes;

  # ---------------------------------------------------------------------------
  # Deployment health check (runtime, on the real host after switch).
  #
  # Why not nixosTest / the NixOS test framework?
  # nixosTest builds a QEMU VM from a config and asserts services start there.
  # That cannot validate this host's post-upgrade reality: Zigbee needs
  # /dev/ttyUSB0, ebusd needs the eBUS bridge, HA needs the live state DB and
  # secrets. Closure size of full HA also makes a VM smoke-test impractical.
  # The right tool is a post-switch probe on the machine that just switched,
  # with generation rollback if anything is still down after a grace period.
  # ---------------------------------------------------------------------------
  healthCheckScript = pkgs.writeShellScript "nixos-deployment-health-check" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [
      pkgs.curl
      pkgs.systemd
      pkgs.coreutils
      pkgs.gnugrep
    ]}:$PATH"

    timeout_sec=${toString hc.timeoutSec}
    interval_sec=${toString hc.intervalSec}
    units=(
    ${lib.concatMapStrings (u: "  ${lib.escapeShellArg u}\n") hc.units}
    )

    echo "=== Deployment health check ($(date)) ==="
    echo "Host: ${hostname}"
    echo "Timeout: ''${timeout_sec}s  interval: ''${interval_sec}s"
    if (( ''${#units[@]} > 0 )); then
      echo "Units: ''${units[*]}"
    else
      echo "Units: (none)"
    fi

    deadline=$((SECONDS + timeout_sec))
    attempt=0

    while true; do
      attempt=$((attempt + 1))
      all_ok=1
      report=""

      for unit in "''${units[@]}"; do
        state=$(systemctl is-active "$unit" 2>/dev/null || true)
        if [[ "$state" != "active" ]]; then
          all_ok=0
          report+="  unit $unit: ''${state:-unknown}"$'\n'
        fi
      done

      ${lib.concatMapStrings (p: ''
      code=$(curl -sS -o /dev/null -w '%{http_code}' \
        --connect-timeout 3 --max-time 10 \
        ${lib.escapeShellArg p.url} 2>/dev/null || echo 000)
      case "$code" in
        ${lib.concatMapStringsSep "|" toString p.acceptStatus})
          ;;
        *)
          all_ok=0
          report+="  http ${p.url}: $code (want ${lib.concatMapStringsSep "," toString p.acceptStatus})"$'\n'
          ;;
      esac
      '') hc.httpProbes}

      if [[ "$all_ok" -eq 1 ]]; then
        echo "All deployment health checks passed (attempt $attempt)."
        exit 0
      fi

      if (( SECONDS >= deadline )); then
        echo "Deployment health check FAILED after ''${timeout_sec}s (attempt $attempt):"
        printf '%s' "$report"
        echo ""
        echo "--- unit status (last 25 lines each) ---"
        for unit in "''${units[@]}"; do
          echo ">>>> $unit"
          systemctl --no-pager --full status "$unit" 2>&1 | head -n 25 || true
          echo ""
        done
        exit 1
      fi

      # Compact one-line progress without spamming the journal too hard.
      echo "not ready yet (attempt $attempt, ''$((deadline - SECONDS))s left): ''${report//$'\n'/; }"
      sleep "$interval_sec"
    done
  '';

  # Shell fragment inserted after a successful switch on this host.
  # On failure: optional rollback, fail marker, discard lock (leader), exit 1.
  # applied_marker must only be written after this succeeds.
  postSwitchHealthCheck = leader: if !hc.enable then "" else ''
    echo "Running post-switch deployment health check..."
    if ! ${healthCheckScript}; then
      echo "=== DEPLOYMENT HEALTH CHECK FAILED on ${hostname} ==="
      ${if hc.rollback then ''
      echo "Rolling back to previous system generation..."
      if nixos-rebuild --rollback switch 2>&1; then
        echo "Rollback to previous generation succeeded."
      else
        echo "CRITICAL: nixos-rebuild --rollback switch FAILED — manual intervention needed."
      fi
      '' else ''
      echo "Rollback disabled (autoUpgrade.healthCheck.rollback = false); leaving new generation active."
      ''}
      echo "$current_hash" > "$fail_marker"
      ${if leader then ''
      echo "Discarding flake.lock changes after failed health check."
      git checkout -- flake.lock
      '' else ""}
      exit 1
    fi
  '';

  # Fired via OnFailure= so timeouts, OOM, and unexpected crashes are mailed
  # too — not only the script's explicit `exit 1` paths. Skip cases (unchanged
  # lock, already-applied, previously-failed hash) exit 0 and do not mail.
  failureMailScript = pkgs.writeShellScript "nixos-auto-upgrade-mail" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [ pkgs.systemd pkgs.coreutils ]}:$PATH"

    result="''${MONITOR_SERVICE_RESULT:-unknown}"
    exit_code="''${MONITOR_EXIT_CODE:-}"
    exit_status="''${MONITOR_EXIT_STATUS:-}"
    invocation="''${MONITOR_INVOCATION_ID:-}"

    logs() {
      if [[ -n "$invocation" ]]; then
        journalctl _SYSTEMD_INVOCATION_ID="$invocation" --no-pager -o short-iso
      else
        journalctl -u nixos-auto-upgrade.service -n 200 --no-pager -o short-iso
      fi
    }

    {
      echo "Subject: [${hostname}] nixos-auto-upgrade FAILED"
      echo "From: ${hostname}@nathan.gs"
      echo "To: ${config.secrets.email}"
      echo "Content-Type: text/plain; charset=UTF-8"
      echo
      echo "nixos-auto-upgrade.service failed on ${hostname} at $(date)."
      echo "result: $result  exit: ''${exit_code:-?} / ''${exit_status:-?}"
      echo
      echo "=== journal (this invocation) ==="
      logs || true
    } | /run/wrappers/bin/sendmail -t
  '';

  autoUpgradeScript = pkgs.writeShellScript "nixos-auto-upgrade" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [
      pkgs.git
      pkgs.nix
      pkgs.nixos-rebuild
      pkgs.coreutils
      pkgs.openssh
      pkgs.curl
      pkgs.systemd
    ]}:$PATH"
    export HOME="/root"

    # Allow nix to read git repos not owned by root (e.g. /etc/nixos/secrets).
    # --replace-all collapses any pre-existing (possibly multi-valued) entries
    # into the single '*' wildcard; a plain `git config` set fails with
    # "cannot overwrite multiple values with a single value".
    git config --global --replace-all safe.directory '*'

    export GIT_AUTHOR_NAME="nixos-auto-upgrade"
    export GIT_AUTHOR_EMAIL="root@${hostname}"
    export GIT_COMMITTER_NAME="nixos-auto-upgrade"
    export GIT_COMMITTER_EMAIL="root@${hostname}"

    # git commands run as root here leave root-owned objects/index/lock files
    # behind in these repos, blocking nathan's own commits afterwards. Hand
    # ownership back on every exit path (success or failure), not just the
    # happy path.
    restore_ownership() {
      chown -R nathan:users ${flakeDir} ${secretsDir} 2>/dev/null || true
    }
    trap restore_ownership EXIT

    cd ${flakeDir}

    # Marker recording the sha256 of a flake.lock whose build, switch, or
    # post-switch health check failed. Used to skip retries on identical
    # inputs while still allowing retries once upstream advances.
    fail_marker="$STATE_DIRECTORY/failed-lock.sha256"
    applied_marker="$STATE_DIRECTORY/applied-lock.sha256"

    echo "=== NixOS Auto-Upgrade: $(date) ==="
    echo "Host: ${hostname}  updateFlake: ${if cfg.updateFlake then "yes" else "no"}  healthCheck: ${if hc.enable then "yes" else "no"}"

    ${if cfg.updateFlake then ''
    # --- Leader: advance flake inputs, switch self, commit, apply remotes ---

    echo "Updating flake inputs..."
    nix flake update 2>&1

    if git diff --quiet flake.lock; then
      echo "flake.lock unchanged — nothing to do."
      exit 0
    fi

    current_hash=$(sha256sum flake.lock | cut -d' ' -f1)
    if [[ -f "$fail_marker" && "$(cat "$fail_marker")" == "$current_hash" ]]; then
      echo "flake.lock matches a previously-failed attempt ($current_hash) — skipping."
      git checkout -- flake.lock
      exit 0
    fi

    echo "flake.lock has changes, evaluating build for ${hostname}..."

    if ! nixos-rebuild build --flake .#${hostname} 2>&1; then
      echo "Build FAILED for ${hostname} — discarding flake.lock changes."
      echo "$current_hash" > "$fail_marker"
      git checkout -- flake.lock
      exit 1
    fi

    # Gate the lock commit on follower configs building too (same arch).
    ${lib.concatMapStrings (attr: ''
    echo "Also building flake config #${attr} before switch..."
    if ! nixos-rebuild build --flake .#${attr} 2>&1; then
      echo "Build FAILED for ${attr} — discarding flake.lock changes."
      echo "$current_hash" > "$fail_marker"
      git checkout -- flake.lock
      exit 1
    fi
    '') remoteFlakeAttrs}

    echo "Build(s) succeeded. Switching ${hostname}..."

    if ! switch_output=$(nixos-rebuild switch --flake .#${hostname} 2>&1); then
      echo "Switch FAILED — discarding flake.lock changes."
      echo "$switch_output"
      echo "$current_hash" > "$fail_marker"
      git checkout -- flake.lock
      exit 1
    fi

    ${postSwitchHealthCheck true}

    rm -f "$fail_marker"
    echo "$current_hash" > "$applied_marker"

    echo "Switch + health check succeeded. Committing flake.lock..."
    git add flake.lock

    commit_msg_file=$(mktemp)
    {
      echo "auto-upgrade: update flake.lock ($(date -u +%Y-%m-%d))"
      echo
      echo "Switch output (${hostname}):"
      echo "--------"
      echo "$switch_output" | tail -n 200
    } > "$commit_msg_file"

    git commit -F "$commit_msg_file" -- flake.lock
    rm -f "$commit_msg_file"

    ${if hasRemotes then ''
    # Propagate nix-conf + secrets via plain git push over the existing
    # nhtpc→nnas SSH key. That is ALL the leader does for a follower: each
    # follower builds and switches itself on its own timer, from the lock it
    # finds in its working tree.
    #
    # Why push instead of "git pull from nhtpc.wg" on the follower?
    # nnas already has origin → nhtpc.wg for secrets, but non-interactive pull
    # needs a key nnas→nhtpc, which does not exist (nathan@nnas has no private
    # key; bin/sync-nnas only works because an interactive session forwards an
    # agent). We already have the reverse direction for media-rsync, so push is
    # the dual that works unattended. Same end state as pull.
    #
    # Why the leader no longer switches the follower over ssh:
    # it coupled the leader's exit status to the follower's switch, so any
    # follower hiccup mailed a failure from nhtpc for an upgrade that had
    # already succeeded locally. The follower has its own failure mail; let it
    # own its own outcome. The leader still gates the flake.lock commit on the
    # follower's config *building* (above), which is the part worth doing here
    # — nhtpc is the faster machine and a broken lock never reaches nnas.
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh ${sshOpts}"

    sync_remote() {
      local user="$1" host="$2"
      local target="''${user}@''${host}"
      local secrets_url="ssh://''${user}@''${host}${secretsDir}"
      local conf_url="ssh://''${user}@''${host}${flakeDir}"

      echo "=== Syncing repos to ''${target} ==="

      # Non-bare checkouts refuse pushes to the current branch unless told
      # otherwise; updateInstead advances the working tree on ff.
      ${pkgs.openssh}/bin/ssh ${sshOpts} "$target" \
        "git -C ${secretsDir} config receive.denyCurrentBranch updateInstead && \
         git -C ${flakeDir} config receive.denyCurrentBranch updateInstead"

      # Secrets first: the rev pinned in flake.lock must exist on the follower
      # before nix-conf lands, or its next build cannot resolve the input.
      # Default push refuses non-ff updates (no --force).
      echo "Pushing secrets to ''${secrets_url}..."
      git -C ${secretsDir} push "$secrets_url" HEAD:refs/heads/main

      echo "Pushing nix-conf to ''${conf_url}..."
      git -C ${flakeDir} push "$conf_url" HEAD:refs/heads/main

      echo "Sync complete for ''${target}; it will switch on its own timer."
    }

    sync_failed=0
    ${lib.concatMapStrings (r: ''
    if ! sync_remote "${r.user}" "${r.host}"; then
      echo "WARNING: repo sync failed for ${r.user}@${r.host}"
      sync_failed=1
    fi
    '') cfg.syncRemotes}

    if [[ "$sync_failed" -ne 0 ]]; then
      echo "Local upgrade committed, but one or more repo syncs failed."
      exit 1
    fi
    '' else ""}

    echo "=== Auto-upgrade complete ==="
    '' else ''
    # --- Follower: apply current flake.lock if not yet applied (no flake update) ---

    current_hash=$(sha256sum flake.lock | cut -d' ' -f1)
    if [[ -f "$applied_marker" && "$(cat "$applied_marker")" == "$current_hash" ]]; then
      echo "flake.lock already applied ($current_hash) — nothing to do."
      exit 0
    fi

    if [[ -f "$fail_marker" && "$(cat "$fail_marker")" == "$current_hash" ]]; then
      echo "flake.lock matches a previously-failed attempt ($current_hash) — skipping."
      exit 0
    fi

    echo "Applying flake.lock ($current_hash) on ${hostname}..."

    if ! nixos-rebuild build --flake .#${hostname} 2>&1; then
      echo "Build FAILED."
      echo "$current_hash" > "$fail_marker"
      exit 1
    fi

    echo "Build succeeded. Switching..."

    if ! switch_output=$(nixos-rebuild switch --flake .#${hostname} 2>&1); then
      echo "Switch FAILED."
      echo "$switch_output"
      echo "$current_hash" > "$fail_marker"
      exit 1
    fi

    ${postSwitchHealthCheck false}

    rm -f "$fail_marker"
    echo "$current_hash" > "$applied_marker"
    echo "$switch_output" | tail -n 50
    echo "=== Auto-upgrade complete (follower) ==="
    ''}
  '';
in
{
  options.autoUpgrade = {
    updateFlake = mkOption {
      type = types.bool;
      default = true;
      description = ''
        If true, this host runs `nix flake update` and commits flake.lock after a
        successful switch (leader). Set false on followers so only one machine
        advances flake inputs.
      '';
    };

    syncRemotes = mkOption {
      type = types.listOf (types.submodule {
        options = {
          host = mkOption {
            type = types.str;
            description = "SSH hostname (e.g. nnas.wg).";
          };
          flakeAttr = mkOption {
            type = types.str;
            description = ''
              nixosConfigurations attribute name on the remote. The leader
              builds it locally before committing flake.lock, so a lock that
              breaks the follower is never published. The leader does not
              switch it — the follower does that itself.
            '';
          };
          user = mkOption {
            type = types.str;
            default = "nathan";
            description = "SSH user on the remote (push target; no sudo needed).";
          };
        };
      });
      default = [ ];
      description = ''
        After a successful local upgrade and flake.lock commit, git-push
        /etc/nixos/secrets and /etc/nixos/nix-conf to each remote over SSH
        (ff-only). Secrets first so the rev pinned in flake.lock exists on the
        remote. Uses the nhtpc→remote key (push is the dual of "pull from
        nhtpc.wg", which needs a reverse key that is not set up
        non-interactively). Only when updateFlake is true.

        Each remote then builds and switches itself on its own timer
        (updateFlake = false), and mails its own failures. The leader
        deliberately does not switch remotes: that coupled the leader's exit
        status to the follower's, so a transient follower problem reported the
        leader's already-successful upgrade as failed.
      '';
    };

    onCalendar = mkOption {
      type = types.listOf types.str;
      # Role-based default: leader early, follower after the leader's push has
      # had time to land. Nothing races any more (the leader only pushes; each
      # host switches itself), so the follower only needs enough margin for the
      # leader's update+build+switch+health-check, observed at ~10 min.
      # The second follower run picks up a leader retry from its 05:00 slot.
      default =
        if cfg.updateFlake then
          [ "*-*-* 04:00:00" "*-*-* 05:00:00" ]
        else
          [ "*-*-* 05:00:00" "*-*-* 05:45:00" ];
      defaultText = lib.literalExpression ''
        if updateFlake
        then [ "*-*-* 04:00:00" "*-*-* 05:00:00" ]
        else [ "*-*-* 05:00:00" "*-*-* 05:45:00" ]
      '';
      description = ''
        systemd OnCalendar expressions for the auto-upgrade timer.
        Leaders default to 04:00/05:00. Followers default to 05:00/05:45,
        leaving the leader room to finish and push before the first run; a run
        that finds no new lock exits immediately, so an early one is free.
      '';
    };

    healthCheck = {
      enable = mkEnableOption ''
        After `nixos-rebuild switch`, poll critical systemd units (and optional
        HTTP endpoints) until healthy or timeout. On failure, optionally
        `nixos-rebuild --rollback switch`, record a fail marker for this
        flake.lock hash, and (on the leader) discard lock changes so they are
        not committed or pushed.
      '';

      units = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "home-assistant.service"
          "ebusd.service"
          "mosquitto.service"
          "zigbee2mqtt.service"
        ];
        description = "systemd units that must be active after switch.";
      };

      httpProbes = mkOption {
        type = types.listOf (types.submodule {
          options = {
            url = mkOption {
              type = types.str;
              description = "URL to GET (typically localhost).";
            };
            acceptStatus = mkOption {
              type = types.listOf types.int;
              # 401/403 still prove the process is answering HTTP.
              default = [ 200 201 204 301 302 401 403 ];
              description = "HTTP status codes treated as healthy.";
            };
          };
        });
        default = [ ];
        example = [
          { url = "http://127.0.0.1:8123/"; }
          { url = "http://127.0.0.1:8080/"; }
        ];
        description = "Optional HTTP readiness probes (in addition to units).";
      };

      timeoutSec = mkOption {
        type = types.ints.positive;
        # Home Assistant often needs several minutes after a package upgrade.
        default = 600;
        description = "Max seconds to wait for all checks to pass.";
      };

      intervalSec = mkOption {
        type = types.ints.positive;
        default = 15;
        description = "Seconds between poll attempts.";
      };

      rollback = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If true, run `nixos-rebuild --rollback switch` when health checks
          fail after a successful switch. The fail marker still prevents
          retrying the same flake.lock hash.
        '';
      };
    };
  };

  config = {
    system.activationScripts.auto-upgrade-credentials = mkIf hasRemotes (
      lib.stringAfter [ "users" ] ''
        mkdir -p ${stateDir}
        chmod 700 ${stateDir}
        ${pkgs.coreutils}/bin/install -m 0600 ${identitySource} ${identityFile}
        ${pkgs.coreutils}/bin/install -m 0644 ${knownHostsSource} ${knownHostsFile}
      ''
    );

    systemd.services.nixos-auto-upgrade = {
      description =
        if cfg.updateFlake then
          "NixOS Auto Upgrade (flake update + build + switch + health check)"
        else
          "NixOS Auto Upgrade (apply flake.lock + build + switch + health check)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      onFailure = [ "nixos-auto-upgrade-mail.service" ];

      # This unit calls `nixos-rebuild switch` on itself. Without this,
      # switch-to-configuration would restart the running nixos-auto-upgrade.service
      # mid-switch, SIGTERM'ing the process driving the switch before it can commit
      # flake.lock or record the failure marker. Leave the running unit untouched.
      restartIfChanged = false;

      serviceConfig = {
        Type = "oneshot";
        ExecStart = autoUpgradeScript;
        User = "root";
        WorkingDirectory = flakeDir;
        StateDirectory = "nixos-auto-upgrade";
        # Large builds + HA health wait can run a while
        TimeoutStartSec = "2h";
      };
    };

    systemd.services.nixos-auto-upgrade-mail = {
      description = "Email when nixos-auto-upgrade fails";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = failureMailScript;
        User = "root";
      };
    };

    # Manual / ad-hoc run of the same probes used after auto-upgrade:
    #   systemctl start nixos-deployment-health-check.service
    systemd.services.nixos-deployment-health-check = mkIf hc.enable {
      description = "Deployment health check (critical smarthome services)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = healthCheckScript;
        User = "root";
      };
    };

    systemd.timers.nixos-auto-upgrade = {
      description = "NixOS Auto Upgrade Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        RandomizedDelaySec = "10m";
        Persistent = true;
      };
    };
  };
}
