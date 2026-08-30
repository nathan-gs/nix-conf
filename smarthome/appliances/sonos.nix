{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {
    sonos.media_player.hosts = [
      "192.168.1.30" # was .140, now kea-reserved (services/dhcp.nix)
      "192.168.1.141" # not seen on the LAN yet, not kea-reserved
      "192.168.1.142" # not seen on the LAN yet, not kea-reserved
      "192.168.1.31" # was .143, now kea-reserved (services/dhcp.nix)
    ];

    # Kitchen One: idle ~4 W (Sonos spec 3.1–4.1 W), playing ~8 W.
    powercalc.sensors = [
      {
        name = "floor0/keuken/sonos";
        unique_id = "floor0_keuken_sonos";
        entity_id = "media_player.floor0_keuken_sonos";
        standby_power = 4;
        fixed.power = ''
          {% if is_state('media_player.floor0_keuken_sonos', 'playing') %}
            8
          {% else %}
            4
          {% endif %}
        '';
      }
    ];
  };

  networking.firewall.allowedTCPPorts = [ 1400 ];

}