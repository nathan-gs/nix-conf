{ config, pkgs, lib, ... }:

{

  services.nzbget = {
    enable = false;
    group = "media";
  };

  networking.firewall.allowedTCPPorts = [ 6789 ];
}
