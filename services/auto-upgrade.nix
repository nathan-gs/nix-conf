{ config, pkgs, lib, ... }:

let
  flakeDir = "/etc/nixos/nix-conf";
  hostname = config.networking.hostName;

  autoUpgradeScript = pkgs.writeShellScript "nixos-auto-upgrade" ''
    set -euo pipefail

    export PATH="${lib.makeBinPath [ pkgs.git pkgs.nix pkgs.nixos-rebuild pkgs.coreutils ]}:$PATH"
    export HOME="/root"
    export GIT_AUTHOR_NAME="nixos-auto-upgrade"
    export GIT_AUTHOR_EMAIL="root@${hostname}"
    export GIT_COMMITTER_NAME="nixos-auto-upgrade"
    export GIT_COMMITTER_EMAIL="root@${hostname}"

    cd ${flakeDir}

    echo "=== NixOS Auto-Upgrade: $(date) ==="

    # Update flake inputs (only writes flake.lock, does not commit)
    echo "Updating flake inputs..."
    nix flake update 2>&1

    # Check if flake.lock actually changed
    if git diff --quiet flake.lock; then
      echo "flake.lock unchanged — nothing to do."
      exit 0
    fi

    echo "flake.lock has changes, evaluating build..."

    # Build to verify the configuration is valid before committing
    if ! nixos-rebuild build --flake .#${hostname} 2>&1; then
      echo "Build FAILED — discarding flake.lock changes."
      git checkout -- flake.lock
      exit 1
    fi

    echo "Build succeeded. Committing flake.lock..."
    git add flake.lock
    git commit -m "auto-upgrade: update flake.lock ($(date -u +%Y-%m-%d))"

    echo "Switching to new configuration..."
    nixos-rebuild switch --flake .#${hostname} 2>&1

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
    };
    # Prevent conflicts with manual nixos-rebuild runs
    unitConfig = {
      X-StopOnReconfiguration = true;
    };
  };

  systemd.timers.nixos-auto-upgrade = {
    description = "NixOS Auto Upgrade Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 04:00:00";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
  };
}
