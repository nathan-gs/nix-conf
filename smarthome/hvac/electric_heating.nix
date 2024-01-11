{ config, pkgs, lib, ha, ... }:

let

  automateTurnOn = v:
    {
      id = "${v}_turn_on";
      alias = "${v}.turn_on";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.${v}_target";
          to = "on";
        }
      ];
      action = [
        {
          service = "switch.turn_on";
          target.entity_id = "switch.${v}";
        }
      ];
      mode = "single";
    };

  automateTurnOff = v:
    {
      id = "${v}_turn_off";
      alias = "${v}.turn_off";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.${v}_target";
          to = "off";
        }
      ];
      action = [
        {
          service = "switch.turn_off";
          target.entity_id = "switch.${v}";
        }
      ];
      mode = "single";
    };

in
{

  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [
          {
            name = "system/wtw/metering_plug/verwarming_target";
            state = ''
              {% set inlet_temp = states('sensor.system_wtw_air_quality_inlet_temperature') | float(5) %}
              {% set not_overheating = inlet_temp < 41 %}
              {% if inlet_temp < -1 %}
                true
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
          }
          {
            name = "floor0/living/metering_plug/verwarming_target";
            state = ''
              {% set sensor = states('floor0_living_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_living_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}
              {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0) %}
              {% set solar_power = states('sensor.electricity_solar_power') | int(0) %}
              {% set battery = states('sensor.solis_remaining_battery_capacity') | int(0) %}
              {% set battery_charged = battery > 80 %}
              {% set solar_power_available = (solar_power - 835 - 250) > 0 %}
              {% set start_on_solar = battery_charged and solar_power_available %}
              {% if (power_available > 835 or start_on_solar) and indoor_temp < 22 %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set in_use = states('input_boolean.floor0_living_in_use') | bool(false) %}
              {% if in_use %}
                00:00:30
              {% else %}
                00:02:00
              {% endif %}
            '';            
            delay_off.seconds = 120;
          }
          {
            name = "floor1/nikolai/metering_plug/verwarming_target";
            state = ''
              {% set sensor = states('sensor.floor1_nikolai_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor1_nikolai_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}              
              {% if power_available > 760 and indoor_temp < 22 %}
                true  
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set in_use = states('input_boolean.floor1_nikolai_in_use') | bool(false) %}
              {% if in_use %}
                00:00:45
              {% else %}
                00:02:00
              {% endif %}
            '';
            delay_off.seconds = 120;
          }
          {
            name = "floor0/bureau/metering_plug/verwarming_target";
            state = ''
              {% set sensor = states('sensor.floor0_bureau_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_bureau_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}              
              {% if power_available > 685 and indoor_temp < 21 %}
                  true  
                {% else %}
                  false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set in_use = states('input_boolean.floor0_bureau_in_use') | bool(false) %}
              {% if in_use %}
                00:01:00
              {% else %}
                00:02:30
              {% endif %}
            '';
            delay_off.seconds = 120;
          }
        ];
      }
    ];

    "automation manual" = []
      ++ map (v: automateTurnOn v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" "floor1_nikolai_metering_plug_verwarming" ]
      ++ map (v: automateTurnOff v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" "floor1_nikolai_metering_plug_verwarming" ];

  };
}
