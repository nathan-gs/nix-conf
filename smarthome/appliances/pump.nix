{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {
    "automation manual" = [ ]
      ++ (ha.automationToggle "garden/garden/pomp"
      {
        triggers = [
          {
            platform = "device";
            type = "action";
            domain = "mqtt";
            subtype = "on";
            discovery_id = "0x2c1165fffe68c1df action_on";
            device_id = "139fe92be206cea2bcba0191c6e40927";
          }
        ];
        entities = [ "switch.garden_garden_plug_pomp" ];
      });
  };
}