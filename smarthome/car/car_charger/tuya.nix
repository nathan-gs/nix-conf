{ config, pkgs, lib, ha, ... }:

{

  services.home-assistant.config = {

    input_boolean = {
      # When ON, charger defaults to "Delayed charge" mode and won't start until explicitly requested
      system_car_charger_charge_on_demand = {
        name = "system/car_charger/charge_on_demand";
        icon = "mdi:ev-station";
      };
      # Toggle ON to start a charging session; resets when charging completes
      system_car_charger_charging_requested = {
        name = "system/car_charger/charging_requested";
        icon = "mdi:car-electric";
      };
    };

    input_number = {
      # Set > 0 to override the auto-calculated current from capacity tariff (in Amps)
      system_car_charger_current_override_a = {
        name = "system/car_charger/current_override_a";
        icon = "mdi:current-ac";
        min = 0;
        max = 16;
        step = 1;
        unit_of_measurement = "A";
        mode = "slider";
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
              {% set override = states('input_number.system_car_charger_current_override_a') | float(0) %}
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

    script = {
      system_car_charger_set_current = {
        alias = "system/car_charger/set_current";
        icon = "mdi:current-ac";
        mode = "restart";
        sequence = [
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
      };
    };

    "automation manual" = [

      # Guard: when charger mode switches to immediate without an explicit charge request, revert to delayed_charge
      (
        ha.automation "system/car_charger/on_demand_guard"
          {
            triggers = [
              (ha.trigger.state_to "select.system_car_charger_charging_mode" "immediate")
            ];
            conditions = [
              (ha.condition.on "input_boolean.system_car_charger_charge_on_demand")
              (ha.condition.off "input_boolean.system_car_charger_charging_requested")
            ];
            actions = [
              (ha.action.delay "00:00:02")
              (ha.action.set_value "select.system_car_charger_charging_mode" "delayed_charge")
            ];
          }
      )

      # Start charging: triggered by toggling input_boolean or notification action
      (
        ha.automation "system/car_charger/start_charge"
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
              (ha.action.delay "00:01:00")
              # Gradually ramp current to target
              {
                service = "script.turn_on";
                target.entity_id = "script.system_car_charger_set_current";
              }
              (ha.action.delay "00:01:00")
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

      # Stop charging: when requested flag is turned off, revert to Delayed charge
      (
        ha.automation "system/car_charger/stop_charge"
          {
            triggers = [
              (ha.trigger.off "input_boolean.system_car_charger_charging_requested")
            ];
            conditions = [
              (ha.condition.on "input_boolean.system_car_charger_charge_on_demand")
            ];
            actions = [
              (ha.action.set_value "select.system_car_charger_charging_mode" "delayed_charge")
            ];
          }
      )

      # Auto-complete: when charger power drops to ~0 for 5 minutes, reset the charge session
      (
        ha.automation "system/car_charger/charge_complete"
          {
            triggers = [
              {
                platform = "numeric_state";
                entity_id = "sensor.system_car_charger_power";
                below = 0.01;
                for.minutes = 5;
              }
            ];
            conditions = [
              (ha.condition.on "input_boolean.system_car_charger_charging_requested")
            ];
            actions = [
              (ha.action.off "input_boolean.system_car_charger_charging_requested")
            ];
          }
      )

      # Dynamically update current when the target changes during an active charge session
      (
        ha.automation "system/car_charger/update_current"
          {
            triggers = [
              (ha.trigger.state "sensor.system_car_charger_target_current")
            ];
            conditions = [
              (ha.condition.on "input_boolean.system_car_charger_charging_requested")
              (ha.condition.on "switch.system_car_charger")
            ];
            actions = [
              {
                service = "script.turn_on";
                target.entity_id = "script.system_car_charger_set_current";
              }
            ];
          }
      )

      # Notify when the charger switch turns on but no charge was requested
      (
        ha.automation "system/car_charger/plugged_in_notify"
          {
            triggers = [
              (ha.trigger.on "switch.system_car_charger")
            ];
            conditions = [
              (ha.condition.on "input_boolean.system_car_charger_charge_on_demand")
              (ha.condition.off "input_boolean.system_car_charger_charging_requested")
            ];
            actions = [
              {
                service = "notify.mobile_app_nphone";
                data = {
                  title = "Car Charger";
                  message = ''
                    Car charger active. Start charging at {{ states('sensor.system_car_charger_target_current') }}A ({{ (states('sensor.system_car_charger_target_current') | float(12) * 230 / 1000) | round(1) }} kW)?
                  '';
                  data = {
                    tag = "tuya_charger_ask";
                    persistent = true;
                    sticky = true;
                    actions = [
                      {
                        action = "TUYA_CHARGER_START";
                        title = "Start Charging";
                      }
                    ];
                  };
                };
              }
            ];
          }
      )

      # Evening ask: prompt to charge tonight
      (
        ha.automation "system/car_charger/ask"
          {
            triggers = [
              (ha.trigger.at "21:30")
            ];
            conditions = [
              (ha.condition.on "input_boolean.system_car_charger_charge_on_demand")
              (ha.condition.off "input_boolean.system_car_charger_charging_requested")
            ];
            actions = [
              {
                service = "notify.mobile_app_nphone";
                data = {
                  title = "Charge Car?";
                  message = ''
                    Start charging at {{ states('sensor.system_car_charger_target_current') }}A ({{ (states('sensor.system_car_charger_target_current') | float(12) * 230 / 1000) | round(1) }} kW)?
                  '';
                  data = {
                    tag = "tuya_charger_ask";
                    persistent = true;
                    sticky = true;
                    actions = [
                      {
                        action = "TUYA_CHARGER_START";
                        title = "Yes, charge";
                      }
                    ];
                  };
                };
              }
            ];
          }
      )

    ];

  };
}
