{ config, lib, pkgs, ... }:

let
  ha = import ./helpers/ha.nix { lib = lib; };

  automation = name: { triggers ? [ ], conditions ? [ ], actions ? [ ], mode ? "single" }: {
    id = builtins.replaceStrings [ "/" "." ] [ "_" "_" ] name;
    alias = name;
    trigger = triggers;
    condition = conditions;
    action = actions;
    mode = mode;
  };

  mqttForward = sensor: mqttTopic: (ha.automation "system/system/dsmr_mqtt_forward/${mqttTopic}" {
    triggers = [ (ha.trigger.state sensor) ];
    conditions = [ ''{{ states('${sensor}') | float(NaN) is number }}'' ];
    actions = [ (ha.action.mqtt_publish mqttTopic ''{{ states('${sensor}') | float(NaN) }}'' true) ];
    mode = "queued";
  });

  sensors = [
    {
      in = "sensor.dsmr_consumption_gas_delivered";
      out = "gas/delivery";
      outExtra = {
        device_class = "gas";
        unit_of_measurement = "m³";
        state_class = "total_increasing";
      };
    }
    {
      in = "sensor.dsmr_consumption_quarter_hour_peak_electricity_average_delivered";
      out = "electricity/delivery/power_15m";
      outExtra = {
        unit_of_measurement = "kW";
        device_class = "power";
      };      
    }
    {
      in = "sensor.dsmr_reading_electricity_currently_delivered";
      out = "electricity/delivery/power_15m";
      outExtra = {
        unit_of_measurement = "kW";
        device_class = "power";
      };      
    }
  ];
in

{
  services.home-assistant.config = {



    "automation manual" =
      (ha.automationOnOff "kerstverlichting"
        {
          triggersOn = [
            {
              platform = "sun";
              event = "sunset";
              offset = "-00:30:00";
            }
            (ha.trigger.at "07:00:00")
          ];
          triggersOff = [
            (ha.trigger.at "23:00:00")
            {
              platform = "sun";
              event = "sunrise";
              offset = "00:30:00";
            }
          ];
          entities = [ "switch.garden_voordeur_light_plug_cirkel" "switch.floor0_living_light_plug_kerstboom" ];
        })
      ++
      (ha.automationOnOff "floor0/living/lights"
        {
          triggersOn = [
            {
              platform = "sun";
              event = "sunset";
              offset = "-00:30:00";
            }
          ];
          triggersOff = [
            (ha.trigger.at "00:00:00")
            (ha.trigger.state_to "input_boolean.floor0_living_in_use" "off")
          ];
          entities = [ "switch.floor0_living_light_plug_kattenlamp" "light.floor0_living_light_bollamp" "light.floor0_living_light_booglamp" ];
        })
      ++
      [

      ];

  };
}
