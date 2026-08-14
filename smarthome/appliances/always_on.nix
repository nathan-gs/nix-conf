{ config, pkgs, lib, ha, ... }:
{
  services.home-assistant.config = {
    # Always-on bits that never hit a metering plug.
    # Repeater: AVM spec ~4 W average / 8.4 W max for FRITZ!Repeater 1200 AX.
    # Zigbee: wall switches + light plugs + non-metered plugs are routers
    # (~0.5 W each). Metering plugs already include their own draw.
    #   5 wall switches + aanrecht light_plug + 3 plugs ≈ 9 × 0.5 W ≈ 5 W.
    powercalc.sensors = [
      {
        name = "system/fritz_repeater";
        unique_id = "system_fritz_repeater";
        entity_id = "binary_sensor.fritz_box_7530_ax_connection";
        standby_power = 4;
        fixed.power = 4;
      }
      {
        name = "zigbee/switches";
        unique_id = "zigbee_switches";
        entity_id = "binary_sensor.fritz_box_7530_ax_connection";
        standby_power = 5;
        fixed.power = 5;
      }
    ];
  };
}
