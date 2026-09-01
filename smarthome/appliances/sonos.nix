{ config, pkgs, lib, ha, ... }:
let
  deviceIp = name: (lib.findFirst (d: d.name == name) (throw "sonos.nix: device '${name}' not in home-network.nix") config.homeNetwork.devices).ip;
in
{

  services.home-assistant.config = {
    sonos.media_player.hosts = map deviceIp [
      "sonos-tv"
      "sonos-keuken"
      "sonos-3"
      "sonos-4"
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