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
            device_id = "ef629f47dff2146250bc005fa879e044";
            discovery_id = "0x84fd27fffe953a0f action_on";
          }
        ];
        entities = [ "switch.garden_garden_plug_pomp" ];
      });
  };
}