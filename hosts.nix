{ config, pkgs, lib, ... }:

{

  # Hosts
  networking.hosts = {
    "192.168.1.126" = [ "solis-s3wifi" ];
    "172.16.8.1" = [ "nhtpc.wg" ];
    "172.16.8.2" = [ "nnas.wg" ];
  };

}
