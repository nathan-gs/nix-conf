{ config, pkgs, lib, ... }:

{

  # Hosts
  networking.hosts = {
    "10.73.221.1" = [ "nhtpc.wg" ];
    # nnas is now reached over nhtpc's own WG server instead of the
    # fritzbox. Only apply this on nhtpc *after* nnas has switched and its
    # peer shows a handshake (`sudo wg show wg0` on nhtpc) — deploying this
    # first would point media-rsync/auto-upgrade at an address nnas isn't
    # listening on yet.
    "10.73.221.2" = [ "nnas.wg" ];

    "10.73.221.10" = [ "nphone.wg" ];
    "10.73.221.11" = [ "nlaptop.wg" ];
    "10.73.221.12" = [ "fphone.wg" ];
  };

}
