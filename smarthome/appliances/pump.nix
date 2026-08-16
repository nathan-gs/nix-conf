{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {
    # Garden pomp on a non-metered zigbee plug. Solis house load stepped
    # ~160–190 W when it came on (21:17) and ~270 W when it went off (22:41)
    # on 2026-08-14 — other loads moved too, so 200 W is the middle.
    # This is the pump for the barrel, move when the new pump arrives.
    powercalc.sensors = [
      {
        name = "garden/pomp";
        unique_id = "garden_pomp";
        entity_id = "switch.garden_garden_plug_pomp";
        standby_power = 0;
        fixed.power = 200;
      }
    ];

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