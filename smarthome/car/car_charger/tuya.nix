{ config, pkgs, lib, ha, ... }:

{

  services.home-assistant.config = {

    input_boolean = {
      # Toggle ON to start a charging session; resets when charging completes
      system_car_charger_charging_requested = {
        name = "system/car_charger/charging_requested";
        icon = "mdi:car-electric";
      };
      car_charge_to_max = {
        name = "car/charge_to_max";
        icon = "mdi:battery-high";
      };
    };

    input_select = {
      system_car_charger_current_override_a = {
        name = "system/car_charger/current_override_a";
        icon = "mdi:current-ac";
        options = [ "6"  "8" "10" "13" "16" "auto" ]; 
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
                {% set capacity_kw = monthly_peak if monthly_peak > 0 else 2.7 %}
                {% set estimated_15m = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
                {% set charger_kw = states('sensor.system_car_charger_power') | float(0) %}
                {% set headroom_kw = capacity_kw - (estimated_15m - charger_kw) %}
                {% set target_a = (headroom_kw * 1000 / 230) | round(0) | int %}
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
      }
    ];

    "automation manual" = [

      # Start charging: triggered by toggling input_boolean or notification action
      (
        ha.automation "system/car_charger.start"
          {
            triggers = [
              (ha.trigger.on "input_boolean.system_car_charger_charging_requested")
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "TUYA_CHARGER_START";
              }
            ];
            actions = [
              # Ensure requested flag is on (in case triggered by notification)
              (ha.action.on "input_boolean.system_car_charger_charging_requested")
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
              # Clear any pending notification
              {
                service = "notify.mobile_app_nphone";
                data = {
                  message = "clear_notification";
                  data.tag = "tuya_charger_ask";
                };
              }
            ];
          }
      )



      # Auto-complete: when charger power drops to ~0 for 5 minutes, reset the charge session
      (
        ha.automation "system/car_charger.charge_complete"
          {
            triggers = [
              (ha.trigger.off_for "binary_sensor.car_charger_charging" "00:05:00")
            ];
            conditions = [
              (ha.condition.on "input_boolean.system_car_charger_charging_requested")
            ];
            actions = [
              (ha.action.off "input_boolean.system_car_charger_charging_requested")
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
              (ha.condition.on "input_boolean.system_car_charger_charging_requested")
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

      # ──────────────────────────────────────────────────────────────
      # The improved solar/soc/offpeak automation
      # ──────────────────────────────────────────────────────────────
      (
        ha.automation "system/car_charger.control"
          {
            triggers = [
              (ha.trigger.on "binary_sensor.electricity_is_offpeak")
              { platform = "time_pattern"; minutes = "/2"; }
              # {
              #   platform = "state";
              #   entity_id = [
              #     "sensor.audi_a6_sportback_e_tron_state_of_charge"
              #     "sensor.solis_remaining_battery_capacity"
              #    "sensor.solar_power_mean_15m"
              #     "sensor.electricity_grid_consumed_power_mean_15m"
              #     "input_boolean.car_charge_to_max"
              #   ];
              # }
            ];
            conditions = [ ];
            actions = [
              {
                choose = [
                  {
                    conditions = [
                      {
                        condition = "template";
                        value_template = "{{ states('sensor.solis_remaining_battery_capacity') | float(10) < 20 }}";
                      }
                    ];
                    sequence = [
                      (ha.action.off "input_boolean.system_car_charger_charging_requested")
                    ];
                  }
                  {
                    conditions = [
                      {
                        condition = "template";
                        value_template = "{{ states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) < 50 }}";
                      }
                    ];
                    sequence = [
                      (ha.action.on "input_boolean.system_car_charger_charging_requested")
                    ];
                  }
                  {
                    conditions = [
                      {
                        condition = "state";
                        entity_id = "binary_sensor.electricity_is_offpeak";
                        state = "on";
                      }
                      {
                        condition = "template";
                        value_template = "{{ states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) < 70 }}";
                      }
                    ];
                    sequence = [
                      (ha.action.on "input_boolean.system_car_charger_charging_requested")
                    ];
                  }
                  {
                    conditions = [
                      {
                        condition = "template";
                        value_template = ''
                          {{ states('sensor.solar_power_mean_15m') | float(0) > 1000
                          and states('sensor.electricity_grid_consumed_power_mean_15m') | float(0) < 100
                          and states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) < (100 if is_state('input_boolean.car_charge_to_max', 'on') else 80)
                          and states('sensor.solis_remaining_battery_capacity') | float(10) > 20 }}
                        '';
                      }
                    ];
                    sequence = [
                      (ha.action.on "input_boolean.system_car_charger_charging_requested")
                    ];
                  }
                ];
                default = [
                  (ha.action.off "input_boolean.system_car_charger_charging_requested")
                ];
              }
            ];
          }
      )

      # Ensure charger is off when not requested
      (
        ha.automation "system/car_charger.stop"
          {
            triggers = [
              (ha.trigger.on "switch.system_car_charger")
              (ha.trigger.on "binary_sensor.car_charger_charging")
              (ha.trigger.off "input_boolean.system_car_charger_charging_requested")
            ];
            conditions = [
              (ha.condition.off "input_boolean.system_car_charger_charging_requested")
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