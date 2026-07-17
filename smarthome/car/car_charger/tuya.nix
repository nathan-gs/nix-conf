{ ha, ... }:

{

  services.home-assistant.config = {

    input_boolean = {
      car_charge_to_max = {
        name = "car/charge_to_max";
        icon = "mdi:battery-high";
      };
      # Set by the 21:00 "plan tomorrow" automation from the solar forecast, so the
      # actionable notification's "Home" reply knows whether to grid-charge to 60% (sunny,
      # solar tops up) or 70% (dull day). See car_charger.plan_tomorrow below.
      car_charge_sunny_tomorrow = {
        name = "car/charge_sunny_tomorrow";
        icon = "mdi:weather-sunny";
      };
      # Set by the 05:00 morning battery boost automation when solar forecast >= 10 kWh and
      # home battery is still >= 60%. Charging runs until the home battery hits 60% (gated in
      # should_charge below), then stops. Reset nightly at 21:00 by plan_tomorrow.
      car_charge_morning_boost = {
        name = "car/charge_morning_boost";
        icon = "mdi:battery-arrow-up";
      };
    };

    input_number = {
      # Overnight grid-charge ceiling (%). The offpeak charger fills to this SoC from the
      # grid; solar tops up the rest during the day. Default 70; the plan_tomorrow flow
      # drops it to 60 on a sunny day or raises it to 100 for a long drive, and resets it
      # to 70 each evening before re-asking.
      # No `initial` so the value restores across HA restarts (a nightly "drive far" 100%
      # survives a 3am restart mid-charge). On the very first boot it comes up at `min`, so
      # min is 60 — the lowest intended target — not something that would starve the charge.
      car_charge_grid_target = {
        name = "car/charge_grid_target";
        icon = "mdi:battery-charging-70";
        min = 60;
        max = 100;
        step = 5;
        unit_of_measurement = "%";
        mode = "slider";
      };
    };

    input_select = {
      car_charge_override = {
        name = "car/charge_override";
        icon = "mdi:car-electric";
        options = [ "auto" "auto + battery" "on" "solar+grid boost" "solar+grid 16a" "off" ];
      };
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
              {# solar+grid boost / 16a: charge as hard as the capacity tariff allows — keep the
                 headroom + peak-shaving logic below, but skip the solar_boost reduction that
                 otherwise caps current to available solar. "solar+grid 16a" additionally lifts
                 the automatic 13A cap to 16A (headroom + peak-shaving tail still hold it under
                 the capacity tariff). #}
              {% set charge_override = states('input_select.car_charge_override') %}
              {% set boost = charge_override in ['solar+grid boost', 'solar+grid 16a'] %}
              {% set battery_mode = charge_override == 'auto + battery' %}
              {% set cap = 16 if charge_override == 'solar+grid 16a' else 13 %}
              {% set override = states('input_select.system_car_charger_current_override_a') | int(0) %}
              {% if override > 0 %}
                {% set target_a = override | int %}
              {% else %}
                {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(0) %}
                {% set capacity_kw = max(monthly_peak, 2.45) %}
                {% set capacity_near = [1.95, monthly_peak - 0.4] | max %}
                {# END-OF-QUARTER peak shaving. The capaciteitstarief peak is the 15-MINUTE AVERAGE of
                   grid import, so we charge hard while little of the quarter is committed, then drop
                   to 6A for the tail so the average lands under the cap.

                   `electricity_delivery_power_15m` (banked) is the average ALREADY committed this
                   quarter; it only climbs (and resets each quarter), so it is the stable trigger.
                   (`electricity_delivery_power_15m_estimated` is the assume-current-power projection —
                   it drops the instant we throttle, so using it as the trigger would chatter; it is
                   what the battery watches instead.)

                   We drop to 6A once banked nears `capacity_near` — the same level at which the
                   battery's own peak branch arms (solar/battery/overdischargesoc_target) — so the car
                   shaves the tail and the battery stays quiet, and it never drained to 10% as on
                   2026-07-03. See docs/ev-battery-peak-coordination.md. #}
                {% set banked = states('sensor.electricity_delivery_power_15m') | float(0) %}
                {% if banked >= (capacity_near) %}
                  {% set target_a = 6 %}
                {% else %}
                  {# front of the quarter: charge at whatever the cap allows, computed from headroom
                     (scales with monthly_peak) rather than a fixed current. #}
                  {% set estimated_15m = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
                  {% set charger_kw = states('sensor.car_charger_power') | int(0) / 1000 %}
                  {% set headroom_kw = capacity_kw - (estimated_15m - charger_kw) %}
                  {% set target_a = (headroom_kw * 1000 / 230) | round(0) | int %}
                {% endif %}
                {% if is_state('binary_sensor.system_car_charger_solar_boost', 'on') and not boost %}
                  {% set solar = states('sensor.electricity_solar_power_mean_15m') | float(0) %}
                  {% if battery_mode %}
                    {# Reserve 500W for the home battery; cap car charging at 8A. #}
                    {% set available = solar - 500 %}
                    {% set solar_a = [0, (available / 230) | round(0) | int] | max %}
                    {% set target_a = min(8, solar_a) %}
                  {% else %}
                    {% set solar_a = (solar / 230) | round(0) | int %}
                    {% set target_a = min(16, solar_a) %}
                    {% set battery = states('sensor.solis_remaining_battery_capacity') | int(0) %}
                    {% set remaining_energy = states('sensor.energy_production_today_remaining') | float(0) %}
                    {% if battery > 50 and battery <= 80 and remaining_energy > 5 %}
                      {% set target_a = 13 %}
                    {% endif %}
                  {% endif %}
                {% endif %}
                {% set target_a = min(target_a, cap) %}
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
              {{ soc < 45 }}
            '';
          }
          {
            name = "system/car_charger/should_charge_offpeak";
            unique_id = "system_car_charger_should_charge_offpeak";
            icon = "mdi:clock-outline";
            state = ''
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {% set offpeak = is_state('binary_sensor.electricity_is_offpeak', 'on') %}
              {# Grid-charge ceiling is set the evening before via the plan_tomorrow flow
                 (60 sunny / 70 default / 100 long drive); falls back to 70. #}
              {% set target = states('input_number.car_charge_grid_target') | float(70) %}
              {# On the solar-first plan (sunny + home, target 60) grid only guarantees the
                 floor OVERNIGHT — the daytime belongs to solar. This matters on weekends,
                 where offpeak runs all day and would otherwise let the grid pre-empt the sun.
                 Weekdays are unaffected (daytime is peak, so offpeak is already false). For
                 higher targets (dull / drive) there is no solar to protect, so daytime
                 offpeak grid charging stays enabled. #}
              {% set solar_first = target <= 60 %}
              {% set daytime = is_state('sun.sun', 'above_horizon') %}
              {{ offpeak and soc < target and not (solar_first and daytime) }}
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
              {{ solar > 1400 and delivery < 0.4 and soc <= soc_threshold and battery > 15 }}
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
              {% set override = states('input_select.car_charge_override') %}
              {# battery_sufficient (house battery > 10%) must gate ONLY solar charging — draining
                 the house battery to feed the car is wasteful. Grid charging (offpeak / low car
                 SoC / manual on) draws from the grid, so a low house battery must NOT stop it,
                 otherwise a battery drained by peak shaving hard-stops the car overnight. #}
              {% set battery_sufficient = is_state('binary_sensor.solar_battery_sufficient', 'on') %}
              {% set low_soc = is_state('binary_sensor.system_car_charger_low_soc', 'on') %}
              {% set should_charge_offpeak = is_state('binary_sensor.system_car_charger_should_charge_offpeak', 'on') %}
              {% set solar_eligible = is_state('binary_sensor.system_car_charger_solar_charge_eligible', 'on') and battery_sufficient %}
              {% set force_on = override in ['on', 'solar+grid boost', 'solar+grid 16a'] %}
              {# Morning battery boost: drain home battery into car before solar arrives. Stops
                 automatically when battery reaches 60% (the template gate below turns false). #}
              {% set battery = states('sensor.solis_remaining_battery_capacity') | int(0) %}
              {% set morning_boost = is_state('input_boolean.car_charge_morning_boost', 'on') and battery > 60 %}
              {{ override != 'off' and (low_soc or should_charge_offpeak or solar_eligible or force_on or morning_boost) }}
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
              (ha.trigger.on "binary_sensor.system_car_charger_solar_charge_eligible")
              (ha.trigger.state_to "input_select.car_charge_override" "on")
              (ha.trigger.state_to "input_select.car_charge_override" "solar+grid boost")
              (ha.trigger.state_to "input_select.car_charge_override" "solar+grid 16a")
              (ha.trigger.state "sensor.solis_remaining_battery_capacity")
              # Grid peak protection can turn switch.system_car_charger off mid-charge (via
              # car_charger.stop). Re-check every 15m and resume: the `should_charge` on +
              # switch off conditions below mean this only restarts an interrupted charge and is
              # a no-op while already charging or when charging genuinely shouldn't run.
              (ha.trigger.time_pattern_minutes "/15")
            ];
            conditions = [
              (ha.condition.on "binary_sensor.system_car_charger_should_charge")
              {
                condition = "template";
                value_template = ''
                  {% set solar_eligible = is_state('binary_sensor.system_car_charger_solar_charge_eligible', 'on') %}
                  {% set override = states('input_select.car_charge_override') in ['on', 'solar+grid boost', 'solar+grid 16a'] %}
                  {% set battery = states('sensor.solis_remaining_battery_capacity') | int(0) %}
                  {% if solar_eligible and not override %}
                    {{ battery >= 20 }}
                  {% else %}
                    true
                  {% endif %}
                '';
              }
              (ha.condition.off "switch.system_car_charger")
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
              (ha.action.delay "00:00:10")
              (ha.action.on "switch.system_car_charger")
              (ha.action.delay "00:00:15")
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

      # Notify (if someone is home):
      #  - 21:50 if the charge override is off (charger won't start tonight)
      #  - 21:55 if either override (charge or current) is not on auto (won't follow the schedule)
      (
        ha.automation "system/car_charger.notify_override_off"
          {
            triggers = [
              { platform = "time"; at = "21:50:00"; id = "off_2150"; }
              { platform = "time"; at = "21:55:00"; id = "notauto_2155"; }
            ];
            conditions = [
              (ha.condition.on "binary_sensor.anyone_home")
            ];
            actions = [
              {
                choose = [
                  {
                    conditions = [
                      { condition = "trigger"; id = "off_2150"; }
                      {
                        condition = "state";
                        entity_id = "input_select.car_charge_override";
                        state = "off";
                      }
                    ];
                    sequence = [
                      {
                        service = "notify.mobile_app_nphone_p10pro";
                        data = {
                          title = "Car charger";
                          message = "Override is set to off — charger will not start tonight.";
                          data.actions = [
                            {
                              action = "car_charger_override_auto";
                              title = "Set to auto";
                            }
                          ];
                        };
                      }
                    ];
                  }
                  {
                    conditions = [
                      { condition = "trigger"; id = "notauto_2155"; }
                      {
                        condition = "template";
                        value_template = ''
                          {{ not is_state('input_select.car_charge_override', 'auto')
                             or not is_state('input_select.system_car_charger_current_override_a', 'auto') }}
                        '';
                      }
                    ];
                    sequence = [
                      {
                        service = "notify.mobile_app_nphone_p10pro";
                        data = {
                          title = "Car charger";
                          message = ''
                            Charger is not on auto — charge: {{ states('input_select.car_charge_override') }}, current: {{ states('input_select.system_car_charger_current_override_a') }}. It won't follow the schedule tonight.
                          '';
                          data.actions = [
                            {
                              action = "car_charger_override_auto";
                              title = "Set both to auto";
                            }
                          ];
                        };
                      }
                    ];
                  }
                ];
              }
            ];
          }
      )

      # Handle actionable notification: set both overrides back to auto
      (
        ha.automation "system/car_charger.notify_override_off.handle_action"
          {
            triggers = [
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charger_override_auto";
              }
            ];
            conditions = [ ];
            actions = [
              (ha.action.set_value "input_select.car_charge_override" "auto")
              (ha.action.set_value "input_select.system_car_charger_current_override_a" "auto")
            ];
          }
      )

      # "auto + battery" mode: revert to normal auto once the home battery is full enough.
      (
        ha.automation "system/car_charger.battery_mode_auto_revert"
          {
            triggers = [
              (ha.trigger.state "sensor.solis_remaining_battery_capacity")
            ];
            conditions = [
              {
                condition = "state";
                entity_id = "input_select.car_charge_override";
                state = "auto + battery";
              }
              {
                condition = "template";
                value_template = ''
                  {{ states('sensor.solis_remaining_battery_capacity') | int(0) >= 80 }}
                '';
              }
            ];
            actions = [
              (ha.action.set_value "input_select.car_charge_override" "auto")
            ];
          }
      )

      # 05:00 — morning battery boost. If today's solar forecast is >= 10 kWh and the home
      # battery is still well-charged (>= 80%), enable morning_boost so the car charges from
      # the home battery until it drops to 60%. Solar will recharge the battery during the day.
      # Only runs in auto mode; skip if override is set to anything else.
      (
        ha.automation "system/car_charger.morning_battery_boost"
          {
            triggers = [
              { platform = "time"; at = "05:00:00"; }
            ];
            conditions = [
              # Respect manual overrides
              {
                condition = "state";
                entity_id = "input_select.car_charge_override";
                state = "auto";
              }
              # Only worthwhile on a good solar day (>= 10 kWh today)
              {
                condition = "template";
                value_template = ''
                  {{ states('sensor.energy_production_today_remaining') | float(0) >= 10 }}
                '';
              }
              # Battery must be above the 60% stop threshold to have anything to give the car
              {
                condition = "template";
                value_template = ''
                  {{ states('sensor.solis_remaining_battery_capacity') | int(0) >= 60 }}
                '';
              }
            ];
            actions = [
              (ha.action.on "input_boolean.car_charge_morning_boost")
            ];
          }
      )

      # 21:00 — plan tomorrow's charge. Reset the grid ceiling to the 70% default, work out
      # whether tomorrow will be sunny (conservative solar forecast + weather.sxw condition),
      # then ask (actionable notification) whether I'll be home or driving far. No answer keeps
      # the safe 70% default. "Home" resolves to 60% (sunny) or 70% via the stored sunny flag;
      # "Drive far" fills to 100%. See handle_action below.
      (
        ha.automation "system/car_charger.plan_tomorrow"
          {
            triggers = [
              { platform = "time"; at = "21:00:00"; }
            ];
            conditions = [ ];
            actions = [
              # Reset to the default before (re)asking, so an unanswered night lands on 70%
              # and yesterday's "drive far"/"sunny" choice never lingers.
              (ha.action.set_value "input_number.car_charge_grid_target" 70)
              # Clear morning boost so it re-evaluates fresh at 05:00 tomorrow.
              (ha.action.off "input_boolean.car_charge_morning_boost")
              # Pull tomorrow's forecast (weather.sxw supports daily forecasts).
              {
                service = "weather.get_forecasts";
                target.entity_id = "weather.sxw";
                data.type = "daily";
                response_variable = "fc";
              }
              # Store the sunny assessment so the async "Home" reply can read it.
              (ha.action.conditional
                [
                  (ha.condition.template ''
                    {% set t = (now() + timedelta(days=1)).date() %}
                    {% set ns = namespace(cond='unknown') %}
                    {% for f in fc['weather.sxw'].forecast %}
                      {% if as_datetime(f.datetime).date() == t %}{% set ns.cond = f.condition %}{% endif %}
                    {% endfor %}
                    {# energy_production_tomorrow always underestimates, so a moderate figure
                       already means a good day; treat as sunny when the sky is clear-ish OR the
                       conservative forecast is high on its own. #}
                    {% set prod = states('sensor.energy_production_tomorrow') | float(0) %}
                    {% set clear = ns.cond in ['sunny', 'partlycloudy', 'clear-night', 'windy-variant'] %}
                    {{ (clear and prod >= 6) or prod >= 10 }}
                  '')
                ]
                [ (ha.action.on "input_boolean.car_charge_sunny_tomorrow") ]
                [ (ha.action.off "input_boolean.car_charge_sunny_tomorrow") ])
              {
                service = "notify.mobile_app_nphone_p10pro";
                data = {
                  title = "Car charge plan for tomorrow";
                  message = ''
                    Solar forecast ~{{ states('sensor.energy_production_tomorrow') | float(0) | round(0) }} kWh (min).
                    {% if is_state('input_boolean.car_charge_sunny_tomorrow', 'on') %}☀️ Sunny — "Home" grid-charges to 60%, solar tops up during the day.{% else %}☁️ Dull — "Home" grid-charges to 70%.{% endif %}
                    "Drive close" 70% · "Drive far" 100% (grid).
                  '';
                  data = {
                    tag = "car_charge_plan";
                    actions = [
                      { action = "car_charge_plan_home"; title = "🏡 Home"; }
                      { action = "car_charge_plan_drive_close"; title = "🚙 Drive close"; }
                      { action = "car_charge_plan_drive_far"; title = "🚗 Drive far"; }
                    ];
                  };
                };
              }
            ];
          }
      )

      # Handle the plan_tomorrow reply: set the overnight grid ceiling and make sure charging
      # will actually run (override back to auto). Confirm back on the same notification tag.
      (
        ha.automation "system/car_charger.plan_tomorrow.handle_action"
          {
            triggers = [
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charge_plan_home";
                id = "home";
              }
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charge_plan_drive_close";
                id = "drive_close";
              }
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charge_plan_drive_far";
                id = "drive_far";
              }
            ];
            conditions = [ ];
            actions = [
              # An explicit plan implies I want charging tonight — clear a lingering "off".
              (ha.action.set_value "input_select.car_charge_override" "auto")
              {
                choose = [
                  # Home: car stays to catch the sun, so grid only to 60% on a sunny day.
                  {
                    conditions = [ { condition = "trigger"; id = "home"; } ];
                    sequence = [
                      (ha.action.set_value "input_number.car_charge_grid_target"
                        "{{ 60 if is_state('input_boolean.car_charge_sunny_tomorrow', 'on') else 70 }}")
                    ];
                  }
                  # Drive close: car is away during the sunny hours (no solar top-up) but only
                  # needs local range — grid to 70% regardless of the forecast.
                  {
                    conditions = [ { condition = "trigger"; id = "drive_close"; } ];
                    sequence = [
                      (ha.action.set_value "input_number.car_charge_grid_target" 70)
                    ];
                  }
                  # Drive far: fill from the grid overnight.
                  {
                    conditions = [ { condition = "trigger"; id = "drive_far"; } ];
                    sequence = [
                      (ha.action.set_value "input_number.car_charge_grid_target" 100)
                    ];
                  }
                ];
              }
              {
                service = "notify.mobile_app_nphone_p10pro";
                data = {
                  title = "Car charge plan for tomorrow";
                  message = ''
                    Grid-charging to {{ states('input_number.car_charge_grid_target') | float(70) | round(0) }}% tonight.
                  '';
                  data.tag = "car_charge_plan";
                };
              }
            ];
          }
      )

    ];

  };
}