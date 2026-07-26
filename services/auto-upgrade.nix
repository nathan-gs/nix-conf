{ config, pkgs, lib, ... }:

let
  inherit (lib) mkOption mkIf types;

  cfg = config.autoUpgrade;
  flakeDir = "/etc/nixos/nix-conf";
  secretsDir = "/etc/nixos/secrets";
  hostname = config.networking.hostName;

  # Remote apply (leader → followers over WireGuard) reuses the nhtpc-backup
  # key already authorized on nnas for media-rsync.
  hasRemotes = cfg.applyRemotes != [ ];
  stateDir = "/var/lib/nixos-auto-upgrade";
  identityFile = "${stateDir}/id_ed25519";
  knownHostsFile = "${stateDir}/known_hosts";

  identitySource = pkgs.writeText "auto-upgrade-id_ed25519" config.secrets.ssh.nhtpc-backup.private;
  knownHostsSource = pkgs.writeText "auto-upgrade-known_hosts" ''
    nnas.wg ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuzacgoV7F8Ep4qwnovJZIDOoSea2mrghb7E2LNWFJz
    192.168.1.201 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINuzacgoV7F8Ep4qwnovJZIDOoSea2mrghb7E2LNWFJz
  '';

  sshOpts = lib.concatStringsSep " " [
    "-i ${identityFile}"
    "-o IdentitiesOnly=yes"
    "-o UserKnownHostsFile=${knownHostsFile}"
    "-o StrictHostKeyChecking=yes"
    "-o BatchMode=yes"
    "-o ConnectTimeout=30"
  ];

  remoteFlakeAttrs = map (r: r.flakeAttr) cfg.applyRemotes;

  autoUpgradeScript = pkgs.writeShellScript "nixos-auto-upgrade" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [
      pkgs.git
      pkgs.nix
      pkgs.nixos-rebuild
      pkgs.coreutils
      pkgs.openssh
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

    cd ${flakeDir}

    # Marker recording the sha256 of a flake.lock whose build or switch failed.
    # Used to skip retries on identical inputs (e.g. broken upstream pin)
    # while still allowing retries once upstream advances.
    fail_marker="$STATE_DIRECTORY/failed-lock.sha256"
    applied_marker="$STATE_DIRECTORY/applied-lock.sha256"

    echo "=== NixOS Auto-Upgrade: $(date) ==="
    echo "Host: ${hostname}  updateFlake: ${if cfg.updateFlake then "yes" else "no"}"

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

    rm -f "$fail_marker"
    echo "$current_hash" > "$applied_marker"

    echo "Switch succeeded. Committing flake.lock..."
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
    # nhtpc→nnas SSH key, then switch on the remote.
    #
    # Why push instead of "git pull from nhtpc.wg" on the follower?
    # nnas already has origin → nhtpc.wg for secrets, but non-interactive pull
    # needs a key nnas→nhtpc (only works with a logged-in agent today).
    # We already have the reverse direction for media-rsync, so push is the
    # dual that works unattended. Same end state as pull.
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh ${sshOpts}"

    apply_remote() {
      local user="$1" host="$2" flake_attr="$3"
      local target="''${user}@''${host}"
      local secrets_url="ssh://''${user}@''${host}${secretsDir}"
      local conf_url="ssh://''${user}@''${host}${flakeDir}"
      local lock_hash
      lock_hash=$(sha256sum flake.lock | cut -d' ' -f1)

      echo "=== Applying upgrade on ''${target} (#''${flake_attr}) ==="

      # Non-bare checkouts refuse pushes to the current branch unless told
      # otherwise; updateInstead advances the working tree on ff.
      ${pkgs.openssh}/bin/ssh ${sshOpts} "$target" \
        "git -C ${secretsDir} config receive.denyCurrentBranch updateInstead && \
         git -C ${flakeDir} config receive.denyCurrentBranch updateInstead"

      # Default push refuses non-ff updates (no --force).
      echo "Pushing secrets to ''${secrets_url}..."
      git -C ${secretsDir} push "$secrets_url" HEAD:refs/heads/main

      echo "Pushing nix-conf to ''${conf_url}..."
      git -C ${flakeDir} push "$conf_url" HEAD:refs/heads/main

      ${pkgs.openssh}/bin/ssh ${sshOpts} "$target" bash -s -- \
        "$flake_attr" "$lock_hash" <<'REMOTE'
    set -euo pipefail
    flake_attr="$1"
    lock_hash="$2"
    flake_dir="/etc/nixos/nix-conf"
    applied_marker="/var/lib/nixos-auto-upgrade/applied-lock.sha256"

    export PATH="/run/current-system/sw/bin:$PATH"

    echo "Building #''${flake_attr}..."
    sudo nixos-rebuild build --flake "''${flake_dir}#''${flake_attr}"

    echo "Switching #''${flake_attr}..."
    sudo nixos-rebuild switch --flake "''${flake_dir}#''${flake_attr}"

    sudo mkdir -p /var/lib/nixos-auto-upgrade
    echo "$lock_hash" | sudo tee "$applied_marker" >/dev/null

    echo "Remote apply complete for #''${flake_attr}."
    REMOTE
    }

    remote_failed=0
    ${lib.concatMapStrings (r: ''
    if ! apply_remote "${r.user}" "${r.host}" "${r.flakeAttr}"; then
      echo "WARNING: remote apply failed for ${r.user}@${r.host} (#${r.flakeAttr})"
      remote_failed=1
    fi
    '') cfg.applyRemotes}

    if [[ "$remote_failed" -ne 0 ]]; then
      echo "Local upgrade committed, but one or more remote applies failed."
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

    applyRemotes = mkOption {
      type = types.listOf (types.submodule {
        options = {
          host = mkOption {
            type = types.str;
            description = "SSH hostname (e.g. nnas.wg).";
          };
          flakeAttr = mkOption {
            type = types.str;
            description = "nixosConfigurations attribute name on the remote.";
          };
          user = mkOption {
            type = types.str;
            default = "nathan";
            description = "SSH user on the remote (needs passwordless sudo).";
          };
        };
      });
      default = [ ];
      description = ''
        After a successful local upgrade and flake.lock commit, git-push
        /etc/nixos/secrets and /etc/nixos/nix-conf to each remote over SSH
        (ff-only), then nixos-rebuild switch there. Secrets first so the rev
        pinned in flake.lock exists on the remote. Uses the nhtpc→remote key
        (push is the dual of "pull from nhtpc.wg", which needs a reverse key
        that is not set up non-interactively). Only when updateFlake is true.
      '';
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
          "NixOS Auto Upgrade (flake update + build + switch)"
        else
          "NixOS Auto Upgrade (apply flake.lock + build + switch)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

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
        # Remote apply + large builds can run a while
        TimeoutStartSec = "2h";
      };
    };

    systemd.timers.nixos-auto-upgrade = {
      description = "NixOS Auto Upgrade Timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        # Leader at 04:00/05:00. Followers use the same window as a safety net
        # if remote apply already ran they exit quickly via applied-lock marker.
        OnCalendar = [ "*-*-* 04:00:00" "*-*-* 05:00:00" ];
        RandomizedDelaySec = "10m";
      };
    };
  };
}
