{ config, pkgs, lib, ha, ... }:

let 
  chargingStates = [ "plugged_in" "waiting" "paused" "charging" "charged"];
  notChargingStates = [ "available" "fault" "fault_unplugged" ];
in 

{

  services.home-assistant.config = {

    input_boolean = {
      car_charge_to_max = {
        name = "car/charge_to_max";
        icon = "mdi:battery-high";
      };
    };

    input_select = {
      system_car_charger_current_override_a = {
        name = "system/car_charger/current_override_a";
        icon = "mdi:current-ac";
        options = [ "auto" "6"  "8" "10" "13" "16" ]; 
      };
    };


    template = [
      {
        sensor = [
          {
            name = "system/car_charger/target_current";
            unique_id = "system_car_charger_target_current";
            unit_of_measurement = "A";
            device_class = "current";
            state_class = "measurement";
            icon = "mdi:current-ac";
            state = ''
              {% set steps = [6, 8, 10, 13, 16] %}
              {% set override = states('input_select.system_car_charger_current_override_a') | int(0) %}
              {% if override > 0 %}
                {% set target_a = override | int %}
              {% else %}
                {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(0) %}
                {% set capacity_kw = max(monthly_peak, 2.45) %}
                {% set estimated_15m = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
                {% set charger_kw = states('sensor.car_charger_power') | int(0) / 1000 %}
                {% set headroom_kw = capacity_kw - (estimated_15m - charger_kw) %}
                {% set target_a = (headroom_kw * 1000 / 230) | round(0) | int %}
                {% if is_state('binary_sensor.system_car_charger_solar_boost', 'on') %}
                  {% set solar = states('sensor.electricity_solar_power_mean_15m') | float(0) %}
                  {% set solar_a = (solar / 230) | round(0) | int %}
                  {% set target_a = min(16, solar_a) %}
                  {% set battery = states('sensor.solis_remaining_battery_capacity') | int(0) %}
                  {% set remaining_energy = states('sensor.energy_production_today_remaining') | float(0) %}
                  {% if battery > 50 and remaining_energy > 5 %}
                    {% set target_a = 13 %}
                  {% endif %}
                {% endif %}
              {% endif %}
              {% set ns = namespace(val=steps[0]) %}
              {% for s in steps %}
                {% if s <= target_a %}
                  {% set ns.val = s %}
                {% endif %}
              {% endfor %}
              {{ ns.val }}
            '';
          }
        ];
        binary_sensor = [
          {
            name = "system/car_charger/low_soc";
            unique_id = "system_car_charger_low_soc";
            icon = "mdi:battery-low";
            state = ''
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {{ soc < 50 }}
            '';
          }
          {
            name = "system/car_charger/should_charge_offpeak";
            unique_id = "system_car_charger_should_charge_offpeak";
            icon = "mdi:clock-outline";
            state = ''
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {% set offpeak = is_state('binary_sensor.electricity_is_offpeak', 'on') %}
              {{ offpeak and soc < 70 }}
            '';
          }
          {
            name = "system/car_charger/solar_charge_eligible";
            unique_id = "system_car_charger_solar_charge_eligible";
            icon = "mdi:solar-power";
            state = ''
              {% set battery = states('sensor.solis_remaining_battery_capacity') | int(10) %}
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {% set solar = states('sensor.electricity_solar_power_mean_15m') | float(0) %}
              {% set delivery = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {% set charge_to_max = is_state('input_boolean.car_charge_to_max', 'on') %}
              {% set soc_threshold = 100 if charge_to_max else 80 %}
              {{ solar > 1400 and delivery < 0.4 and soc <= soc_threshold and battery > 20 }}
            '';
          }
          {
            name = "system/car_charger/solar_boost";
            unique_id = "system_car_charger_solar_boost";
            icon = "mdi:solar-power-variant";
            state = ''
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {% set solar = states('sensor.electricity_solar_power_mean_15m') | float(0) %}
              {{ soc <= 80 and solar > 1000 }}
            '';
          }
          {
            name = "system/car_charger/should_charge";
            unique_id = "system_car_charger_should_charge";
            icon = "mdi:car-electric";
            state = ''
              {% set battery_sufficient = is_state('binary_sensor.solar_battery_sufficient', 'on') %}
              {% set low_soc = is_state('binary_sensor.system_car_charger_low_soc', 'on') %}
              {% set should_charge_offpeak = is_state('binary_sensor.system_car_charger_should_charge_offpeak', 'on') %}
              {% set solar_eligible = is_state('binary_sensor.system_car_charger_solar_charge_eligible', 'on') %}
              {{ battery_sufficient and (low_soc or should_charge_offpeak or solar_eligible) }}
            '';
          }
        ];
      }
    ];

    "automation manual" = [

      # Start charging: triggered when offpeak charging is needed
      (
        ha.automation "system/car_charger.start"
          {
            triggers = [
              (ha.trigger.on "binary_sensor.system_car_charger_should_charge")
            ];
            actions = [
              # Ensure charger switch is on
              (ha.action.on "switch.system_car_charger")
              (ha.action.delay "00:00:15")
              # Gradually ramp current to target
              {
                service = "automation.trigger";
                target.entity_id = "automation.system_car_charger_set_current";
              }
              (ha.action.delay "00:00:10")
              # Set to immediate charging
              (ha.action.set_value "select.system_car_charger_charging_mode" "immediate")
            ];
          }
      )




      # Set current automation (combines update and set)
      (
        ha.automation "system/car_charger.set_current"
          {
            triggers = [
              (ha.trigger.state "sensor.system_car_charger_target_current")
            ];
            conditions = [
              (ha.condition.on "binary_sensor.system_car_charger_should_charge")
              (ha.condition.on "switch.system_car_charger")
            ];
            mode = "restart";
            actions = [
              {
                repeat = {
                  while = [
                    {
                      condition = "template";
                      value_template = ''
                        {% set current = states('number.system_car_charger_charging_current') | int(6) %}
                        {% set target = states('sensor.system_car_charger_target_current') | int(12) %}
                        {{ current != target }}
                      '';
                    }
                  ];
                  sequence = [
                    {
                      service = "number.set_value";
                      target.entity_id = "number.system_car_charger_charging_current";
                      data.value = ''
                        {% set steps = [6, 8, 10, 13, 16] %}
                        {% set current = states('number.system_car_charger_charging_current') | int(6) %}
                        {% set target = states('sensor.system_car_charger_target_current') | int(6) %}
                        {% if target > current %}
                          {% set ns = namespace(val=target) %}
                          {% for s in steps %}
                            {% if s > current and s < ns.val %}
                              {% set ns.val = s %}
                            {% endif %}
                          {% endfor %}
                          {{ ns.val }}
                        {% elif target < current %}
                          {% set ns = namespace(val=target) %}
                          {% for s in steps | reverse %}
                            {% if s < current and s > ns.val %}
                              {% set ns.val = s %}
                            {% endif %}
                          {% endfor %}
                          {{ ns.val }}
                        {% else %}
                          {{ current }}
                        {% endif %}
                      '';
                    }
                    (ha.action.delay "00:01:00")
                  ];
                };
              }
            ];
          }
      )

      

      # Ensure charger is off when not needed
      (
        ha.automation "system/car_charger.stop"
          {
            triggers = [
              (ha.trigger.on "switch.system_car_charger")
              (ha.trigger.on "binary_sensor.car_charger_charging")
              (ha.trigger.off "binary_sensor.system_car_charger_should_charge")
            ];
            conditions = [
              (ha.condition.off "binary_sensor.system_car_charger_should_charge")
            ];
            actions = [
              (ha.action.off "switch.system_car_charger")
              (ha.action.delay "00:00:05")
              (ha.action.set_value "number.system_car_charger_timer" 6)
              (ha.action.delay "00:00:05")
              (ha.action.set_value "select.system_car_charger_charging_mode" "delayed_charge")
            ];
          }
      )

    ];

  };
}