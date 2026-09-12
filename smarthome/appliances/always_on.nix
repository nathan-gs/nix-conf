{ config, pkgs, lib, ha, ... }:
{
  services.home-assistant.config = {
    # Always-on bits that never hit a metering plug.
    #
    # These used to hang off `binary_sensor.fritz_box_7530_ax_connection` as
    # their source entity. That entity is gone — the FritzBox was replaced by
    # the Orange/Technicolor router — so powercalc had nothing to read and both
    # sensors went `unavailable`. They are unconditionally-on loads anyway, so
    # use powercalc's `sensor.dummy` sentinel, which is always treated as `on`
    # and never depends on another integration staying alive.
    #
    # Repeater: AVM spec ~4 W average / 8.4 W max for FRITZ!Repeater 1200 AX.
    # Zigbee: wall switches + light plugs + non-metered plugs are routers
    # (~0.5 W each). Metering plugs already include their own draw.
    #   5 wall switches + aanrecht light_plug + 3 plugs ≈ 9 × 0.5 W ≈ 5 W.
    #
    # Grouped with the two metered network plugs (router + server) into
    # `system/network`, so everything network-ish rolls up into one
    # power/energy pair instead of floating around unattached.
    powercalc.sensors = [
      {
        create_group = "system/network";
        entities = [
          {
            name = "system/fritz_repeater";
            unique_id = "system_fritz_repeater";
            entity_id = "sensor.dummy";
            fixed.power = 4;
          }
          {
            name = "zigbee/switches";
            unique_id = "zigbee_switches";
            entity_id = "sensor.dummy";
            fixed.power = 5;
          }
          {
            power_sensor_id = "sensor.system_network_metering_plug_router_power";
            energy_sensor_id = "sensor.system_network_metering_plug_router_energy";
          }
          {
            power_sensor_id = "sensor.system_network_metering_plug_server_power";
            energy_sensor_id = "sensor.system_network_metering_plug_server_energy";
          }
        ];
      }
    ];
  };
}
