{ config, pkgs, lib, ... }:

{

  # Hosts
  networking.hosts = {
    "192.168.1.126" = [ "solis-s3wifi" ];
    "192.168.1.2" = [ "nhtpc.wg" ];
    # NOTE: still 192.168.1.201 (fritzbox-routed WG) intentionally — nnas's
    # peer config has moved to 10.10.10.2 on nhtpc's WG server but hasn't
    # been applied yet (see computers/nnas.nix). Update this to 10.10.10.2
    # — together with services/media-rsync.nix and services/auto-upgrade.nix
    # known_hosts — in the same switch that flips nnas over, not before:
    # nhtpc's own auto-upgrade applies nightly and this file is shared, so
    # changing it early breaks media-rsync/auto-upgrade connectivity to nnas
    # while nnas is still only reachable at the old address.
    "192.168.1.201" = [ "nnas.wg" ];
  };

}
