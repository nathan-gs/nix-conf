{ config, pkgs, lib, ha, ... }:

let
  autoWantedHeader = import ./temperature_sets.nix;

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
              {% set inlet_temp_aq = states('sensor.system_wtw_air_quality_inlet_temperature') | float(5) %}
              {% set inlet_temp_wtw = states('sensor.itho_wtw_inlet_temperature') | float(5) %}
              {% set not_overheating = inlet_temp_aq < 41 %}
              {% if inlet_temp_wtw < 0.1 and not_overheating %}
                true
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_off = "00:00:10";
          }
          {
            name = "floor0/living/metering_plug/verwarming_target";
            state = ''
              ${autoWantedHeader}
              {% set sensor = states('floor0_living_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power_min_1m') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_living_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}
              {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0) %}
              {% set solar_power = states('sensor.electricity_solar_power') | int(0) %}
              {% set battery = states('sensor.solis_remaining_battery_capacity') | int(0) %}
              {% set battery_charged = battery > 85 %}
              {% set solar_power_available = (solar_power - 760 - 250) > 0 %}
              {% set start_on_solar = battery_charged and solar_power_available %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% set needs_heating = (states('sensor.floor0_living_temperature_diff_wanted') | float(0)) > 0.7 %}
              {% if far_away %}
                false
              {% elif (power_available > 760 or start_on_solar) and indoor_temp < temperature_max %}
                true  
              {% elif needs_heating and use_electric %}
                true
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              00:02:00              
            '';            
            delay_off.seconds = 120;
          }
          {
            name = "floor1/nikolai/metering_plug/verwarming_target";
            state = ''
              ${autoWantedHeader}
              {% set sensor = states('sensor.floor1_nikolai_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power_min_1m') | float(0) %}
              {% set indoor_temp = states('sensor.floor1_nikolai_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}
              {% set needs_heating = (states('sensor.floor1_nikolai_temperature_diff_wanted') | float(0)) > 0.7 %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% if far_away %}
                false
              {% elif power_available > 750 and indoor_temp < temperature_max %}
                true 
              {% elif needs_heating and use_electric %}
                true
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set needs_heating = (states('sensor.floor1_nikolai_temperature_diff_wanted') | float(0)) > 0.7 %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% if use_electric and needs_heating %}
                00:00:00
              {% else %}
                00:02:00
              {% endif %}
            '';
            delay_off = ''
              {% set power_not_near_max_threshold = not(states('binary_sensor.electricity_delivery_power_near_max_threshold') | bool(false)) %}
              {{ "00:02:00" if power_not_near_max_threshold else "00:00:00" }}
            '';
          }
          {
            name = "floor0/bureau/metering_plug/verwarming_target";
            state = ''
              ${autoWantedHeader}
              {% set sensor = states('sensor.floor0_bureau_metering_plug_verwarming_power') | float(0) %}
              {% set house_return = states('sensor.electricity_grid_returned_power_min_1m') | float(0) %}
              {% set indoor_temp = states('sensor.floor0_bureau_temperature') | float(21) %}
              {% set power_available = (house_return + sensor) %}      
              {% set needs_heating = (states('sensor.floor0_bureau_temperature_diff_wanted') | float(0)) > 0.7 %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% if far_away %}
                false
              {% elif power_available > 700 and indoor_temp < temperature_max %}
                true  
              {% elif needs_heating and use_electric %}
                true
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set needs_heating = (states('sensor.floor0_bureau_temperature_diff_wanted') | float(0)) > 0.7 %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% if use_electric and needs_heating %}
                00:00:00
              {% else %}
                00:02:30
              {% endif %}
            '';
            delay_off = ''
              {% set power_not_near_max_threshold = not(states('binary_sensor.electricity_delivery_power_near_max_threshold') | bool(false)) %}
              {{ "00:02:00" if power_not_near_max_threshold else "00:00:00" }}
            '';
          }
          {
            name = "floor1/badkamer/metering_plug/verwarming_target";
            state = ''
              ${autoWantedHeader}
              {% set needs_heating = (states('sensor.floor1_badkamer_temperature_diff_wanted') | float(0)) > 0.7 %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% if needs_heating and use_electric %}
                true
              {% else %}
                false
              {% endif %}
            '';
            device_class = "heat";
            delay_on = ''
              {% set needs_heating = (states('sensor.floor1_badkamer_temperature_diff_wanted') | float(0)) > 0.7 %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% if use_electric and needs_heating %}
                00:00:00
              {% else %}
                00:03:00
              {% endif %}
            '';
            delay_off = ''
              {% set power_not_near_max_threshold = not(states('binary_sensor.electricity_delivery_power_near_max_threshold') | bool(false)) %}
              {{ "00:02:00" if power_not_near_max_threshold else "00:00:00" }}
            '';
          }
        ];
      }
    ];

    "automation manual" = []
      ++ map (v: automateTurnOn v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" "floor1_nikolai_metering_plug_verwarming" "floor1_badkamer_metering_plug_verwarming"]
      ++ map (v: automateTurnOff v) [ "system_wtw_metering_plug_verwarming" "floor0_living_metering_plug_verwarming" "floor0_bureau_metering_plug_verwarming" "floor1_nikolai_metering_plug_verwarming" "floor1_badkamer_metering_plug_verwarming"];

    recorder = {
      include = {
        entities = [
        ];
        entity_globs = [
          "binary_sensor.*_verwarming_target"
        ];

      };      
    };
  };

}
