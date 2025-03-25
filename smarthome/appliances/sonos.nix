{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {
    sonos.media_player.hosts = [
      "192.168.1.140"
      "192.168.1.141"
      "192.168.1.142"
      "192.168.1.143"
    ];
  };

  networking.firewall.allowedTCPPorts = [ 1400 ];

}