{ config, pkgs, lib, ... }:

{

  # Hosts
  networking.hosts = {
    "192.168.1.126" = [ "solis-s3wifi" ];
    "192.168.1.2" = [ "nhtpc.wg" ];
    "192.168.1.201" = [ "nnas.wg" ];
  };

}
