{ config, pkgs, lib, ... }:

let
  flakeDir = "/etc/nixos/nix-conf";
  hostname = config.networking.hostName;

  autoUpgradeScript = pkgs.writeShellScript "nixos-auto-upgrade" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [ pkgs.git pkgs.nix pkgs.nixos-rebuild pkgs.coreutils pkgs.util-linux ]}:$PATH"
    export HOME="/root"

    # Allow nix (which still runs as root) to read git repos not owned by root
    # (e.g. /etc/nixos/secrets).
    git config --global safe.directory '*'

    cd ${flakeDir}

    # Run git as the repo owner so .git/* objects don't flip to root.
    # Author/committer identity is forced via env so the commit metadata is
    # consistent regardless of who owns the repo.
    repo_owner=$(stat -c '%U' .)
    git() {
      runuser -u "$repo_owner" --preserve-environment -- \
        ${pkgs.git}/bin/git "$@"
    }
    export GIT_AUTHOR_NAME="nixos-auto-upgrade"
    export GIT_AUTHOR_EMAIL="root@${hostname}"
    export GIT_COMMITTER_NAME="nixos-auto-upgrade"
    export GIT_COMMITTER_EMAIL="root@${hostname}"

    # Marker recording the sha256 of a flake.lock whose build or switch failed.
    # Used to skip retries on identical inputs (e.g. broken upstream pin)
    # while still allowing retries once upstream advances.
    fail_marker="$STATE_DIRECTORY/failed-lock.sha256"

    # `nix flake update` and `git checkout` here run as root and would otherwise
    # leave flake.lock owned by root, blocking the next interactive `nix flake update`.
    # Capture the pre-run owner and restore it on every exit path.
    lock_owner=$(stat -c '%u:%g' flake.lock)
    trap 'chown "$lock_owner" flake.lock 2>/dev/null || true' EXIT

    echo "=== NixOS Auto-Upgrade: $(date) ==="

    # Update flake inputs (only writes flake.lock, does not commit)
    echo "Updating flake inputs..."
    nix flake update 2>&1

    # Check if flake.lock actually changed
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

    echo "flake.lock has changes, evaluating build..."

    # Build to verify the configuration is valid before committing
    if ! nixos-rebuild build --flake .#${hostname} 2>&1; then
      echo "Build FAILED — discarding flake.lock changes."
      echo "$current_hash" > "$fail_marker"
      git checkout -- flake.lock
      exit 1
    fi

    echo "Build succeeded. Switching to new configuration..."

    # Capture switch output and exit code so we can include the result
    # in the commit message and rollback on failure.
    if ! switch_output=$(nixos-rebuild switch --flake .#${hostname} 2>&1); then
      echo "Switch FAILED — discarding flake.lock changes."
      echo "$switch_output"
      echo "$current_hash" > "$fail_marker"
      git checkout -- flake.lock
      exit 1
    fi

    rm -f "$fail_marker"

    echo "Switch succeeded. Committing flake.lock..."
    git add flake.lock

    # Pipe the commit message via stdin so we don't need a temp file readable
    # by the user git now runs as.
    {
      echo "auto-upgrade: update flake.lock ($(date -u +%Y-%m-%d))"
      echo
      echo "Switch output:"
      echo "--------"
      echo "$switch_output" | tail -n 200
    } | git commit -F - -- flake.lock

    echo "=== Auto-upgrade complete ==="
  '';
in
{
  systemd.services.nixos-auto-upgrade = {
    description = "NixOS Auto Upgrade (flake update + build + switch)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = autoUpgradeScript;
      User = "root";
      WorkingDirectory = flakeDir;
      StateDirectory = "nixos-auto-upgrade";
    };
  };

  systemd.timers.nixos-auto-upgrade = {
    description = "NixOS Auto Upgrade Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = [ "*-*-* 04:00:00" "*-*-* 05:00:00" ];
      RandomizedDelaySec = "10m";
    };
  };
}
