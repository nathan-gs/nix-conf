{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {

    utility_meter = {
      electricity_delivery_15m = {
        source = "sensor.electricity_delivery";
        cron = "*/15 * * * *";
      };
    };

    mqtt.sensor = [
      {
        name = "electricity_delivery_power_monthly_15m_max";
        unique_id = "electricity_delivery_power_monthly_15m_max";
        state_topic = "dsmr/consumption/peak/running_month";
        unit_of_measurement = "kW";
        device_class = "power";
        force_update = true;
        icon = "mdi:meter-electric";
        state_class = "measurement";
        value_template = "{{ value | round(2) }}";
      }
      # Fluvius billable capacity (kW) from dsmr last13months telegram.
      # Raw payload is ~560 chars (over HA's 255 state limit) — parse in-template.
      # State: rolling 12-month avg (each peak floored at 2.5 kW); mid-month estimate
      # uses 11 completed months + current running_month peak.
      # Telegram: (N)(OBIS)(OBIS)(period)(peak_ts)(NN.NNN*kW)...
      {
        name = "electricity_capacity_peak_12months";
        unique_id = "electricity_capacity_peak_12months";
        state_topic = "dsmr/consumption/peak/last13months";
        unit_of_measurement = "kW";
        device_class = "power";
        state_class = "measurement";
        force_update = true;
        icon = "mdi:meter-electric";
        value_template = ''
          {% set floor_kw = 2.5 %}
          {% set current = [floor_kw, states('sensor.electricity_delivery_power_monthly_15m_max') | float(floor_kw)] | max %}
          {% set peaks = namespace(v=[]) %}
          {% for m in value | regex_findall('([0-9]+\\.[0-9]+)\\*kW') %}
            {% set peaks.v = peaks.v + [[m | float, floor_kw] | max] %}
          {% endfor %}
          {% set completed = peaks.v %}
          {% if completed | length == 0 %}
            {{ current | round(2) }}
          {% elif completed | length >= 12 %}
            {% set window = completed[-11:] + [current] %}
            {{ (window | sum / 12) | round(2) }}
          {% else %}
            {% set window = completed + [current] %}
            {{ (window | sum / (window | length)) | round(2) }}
          {% endif %}
        '';
        json_attributes_template = ''
          {% set floor_kw = 2.5 %}
          {% set peaks = namespace(raw=[], floored=[]) %}
          {% for m in value | regex_findall('([0-9]+\\.[0-9]+)\\*kW') %}
            {% set peaks.raw = peaks.raw + [m] %}
            {% set peaks.floored = peaks.floored + [[m | float, floor_kw] | max] %}
          {% endfor %}
          {% set n = peaks.floored | length %}
          {% set completed_avg = (peaks.floored[-12:] | sum / ([n, 12] | min)) if n > 0 else none %}
          {{ {
            "peaks_kw": peaks.raw | join(','),
            "completed_count": n,
            "completed_12months_avg": (completed_avg | round(3)) if completed_avg is not none else none,
            "current_month_peak": [floor_kw, states('sensor.electricity_delivery_power_monthly_15m_max') | float(floor_kw)] | max
          } | to_json }}
        '';
      }
    ];

    template = [  
      {
        sensor = [
          {
            name = "electricity_delivery_power_15m";
            unique_id = "electricity_delivery_power_15m";
            state = "{{ states('sensor.dsmr_consumption_quarter_hour_peak_electricity_average_delivered') | float(0) }}";
            unit_of_measurement = "kW";
            state_class = "measurement";
            device_class = "power";
          }
          {
            name = "electricity_delivery_power_daily_15m_max";
            unique_id = "electricity_delivery_power_daily_15m_max";
            state = ''
              {% set electricity_delivery_power_15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% set electricity_delivery_power_daily_15m_max = this.state | float(0) %}
              {% if ((now().hour == 0) and (now().minute < 15)) %}
                {{ electricity_delivery_power_15m }}
              {% else %}
                {% if electricity_delivery_power_daily_15m_max < electricity_delivery_power_15m %}
                  {{ electricity_delivery_power_15m }}
                {% else %}
                  {{ electricity_delivery_power_daily_15m_max }} 
                {% endif %}
              {% endif %}
            '';
            unit_of_measurement = "kW";
            state_class = "measurement";
            device_class = "power";
          }
          {
            name = "electricity_delivery_power_15m_estimated";
            unique_id = "electricity_delivery_power_15m_estimated";
            unit_of_measurement = "kW";
            state = ''
              {% set seconds_left = (15 - now().minute % 15) * 60 - now().second % 60 %}
              {# workaround because power_15m reports the previous value for ~ 10s after the quarter #}
              {% if seconds_left < (15 * 60 - 30)  %}
                {% set power_15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% else %}
                {% set power_15m = 0 %}
              {% endif %}
              {% set current_power = (states('sensor.electricity_grid_consumed_power_mean_1m') | float(states('sensor.electricity_grid_consumed_power') | float(0))) / 1000 %}
              {% set current_power_till_end = (current_power * seconds_left) / (3600 / 4) %}
              {{ ((current_power_till_end + power_15m)) | round(2) }}
            '';
            state_class = "measurement";
            device_class = "power";
          }
        ];
        binary_sensor = [
          {
            name = "electricity_high_usage";
            unique_id = "electricity_high_usage";
            state = ''
              {% set is_high = false %}
              {# Wasmachine #}
              {% set is_washing = is_state('sensor.aeg_wasmachine_cyclephase', "Wash") %}
              {% if is_washing %}
                {% set is_high = true %}
              {% endif %}
              {# oven #}
              {% set oven_on = states('sensor.floor0_keuken_metering_plug_oven_power') | int(0) > 1000 %}
              {% if oven_on %}
                {% set is_high = true %}
              {% endif %}
              {# Bathroom Heating #}
              {% set bathroom_heating_on = states('switch.floor1_badkamer_metering_plug_verwarming') | bool(false) %}
              {% if bathroom_heating_on %}
                {% set is_high = true %}
              {% endif %}
              {# car charger #}
              {% set car_charger_on = states('sensor.car_charger_power') | int(0) > 20 %}
              {% if car_charger_on %}
                {% set is_high = true %}
              {% endif %}
              {% if states('sensor.electricity_grid_consumed_power') | int(0) < 1000 %}
                {% set is_high = false %}
              {% endif %}
              {% if states('sensor.electricity_delivery_power_15m_estimated') | float(0) > 1.5 %}
                {% set is_high = true %}
              {% endif %}
              {% if is_state('binary_sensor.electricity_delivery_power_near_max_threshold', "on") %}
                {% set is_high = true %}
              {% endif %}
              {{ is_high }}
            '';
            delay_off.seconds = 120;
            device_class = "running";
          }       
          {
            # Capaciteitstarief floor is 2.5 kW. Do NOT use electricity_delivery_power_15m_estimated
            # here: that assumes current power continues, and while the car is charging hard early
            # in the quarter the projection sits on the cap — even though tuya.nix will throttle
            # (headroom + 6A tail) and land under the peak. Alerts are for loads we cannot
            # auto-shave: project the quarter *excluding* the car charger, so we only fire when
            # the peak is still inevitable after the car scales down (or is already banked).
            name = "electricity_delivery_power_max_threshold";
            unique_id = "electricity_delivery_power_max_threshold";
            state = ''
              {% set seconds_left = (15 - now().minute % 15) * 60 - now().second % 60 %}
              {% if seconds_left < (15 * 60 - 30) %}
                {% set banked = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% else %}
                {% set banked = 0 %}
              {% endif %}
              {% set current_kw = (states('sensor.electricity_grid_consumed_power_mean_1m') | float(states('sensor.electricity_grid_consumed_power') | float(0))) / 1000 %}
              {% set charger_kw = states('sensor.car_charger_power') | int(0) / 1000 %}
              {% set residual_kw = [0, current_kw - charger_kw] | max %}
              {% set projected = banked + (residual_kw * seconds_left) / 900 %}
              {% set monthly_peak = [2.5, states('sensor.electricity_delivery_power_monthly_15m_max') | float(0)] | max %}
              {{ (banked > 1.5) and (projected >= monthly_peak) }}
            '';
          }
          {
            # Same car-excluded projection as max_threshold; early-warn only in the billable band.
            name = "electricity_delivery_power_near_max_threshold";
            unique_id = "electricity_delivery_power_near_max_threshold";
            state = ''
              {% set seconds_left = (15 - now().minute % 15) * 60 - now().second % 60 %}
              {% if seconds_left < (15 * 60 - 30) %}
                {% set banked = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% else %}
                {% set banked = 0 %}
              {% endif %}
              {% set current_kw = (states('sensor.electricity_grid_consumed_power_mean_1m') | float(states('sensor.electricity_grid_consumed_power') | float(0))) / 1000 %}
              {% set charger_kw = states('sensor.car_charger_power') | int(0) / 1000 %}
              {% set residual_kw = [0, current_kw - charger_kw] | max %}
              {% set projected = banked + (residual_kw * seconds_left) / 900 %}
              {% set monthly_peak = [2.5, states('sensor.electricity_delivery_power_monthly_15m_max') | float(0)] | max %}
              {% set threshold = [2.5, monthly_peak - 0.3] | max %}
              {{ (banked > 1.2) and (projected > threshold) }}
            '';
          }
          {
            # Hard last-resort safeguard, general (not car-specific) so any load can react to it.
            # `max_threshold` above already projects the quarter *excluding* whatever the car is
            # drawing right now — so if it's on, the cap is going to be breached by other load
            # alone, no matter how far the car throttles (its 6A tail is a floor, not zero).
            # Only genuinely "critical" once the battery has nothing left to give either
            # (solar/battery/sufficient off, its floor per docs/ev-battery-peak-coordination.md) —
            # otherwise the battery is expected to cover the gap and this should stay quiet.
            name = "electricity_capacity_critical";
            unique_id = "electricity_capacity_critical";
            icon = "mdi:transmission-tower-off";
            state = ''
              {{ is_state('binary_sensor.electricity_delivery_power_max_threshold', 'on') and not is_state('binary_sensor.solar_battery_sufficient', 'on') }}
            '';
          }
        ];
      }
    ];



    "automation manual" = [
      {
        id = "electricity_delivery_power_max_threshold_notify";
        alias = "electricity_delivery_power_max_threshold.notify";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_max_threshold";
            to = "on";
          }
        ];
        condition = [];
        action = [
          {
            service = "notify.notify";
            data = {
              title = "Electricity Peak";
              message = ''
                {% set electricity_delivery_power_15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
                {% set electricity_delivery_power_15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
                {% set currently_delivered = states('sensor.dsmr_reading_electricity_currently_delivered') | float(0) * 1000 %}
                {% set minutes_remaining = (now().minute // 15 + 1) * 15 - now().minute %}
                {% set battery = states('sensor.system_house_pv_battery_soc') %}
                {% set overdischargesoc = states('number.system_house_pv_overdischarge_soc') %}
                Currently at capacity peak {{ electricity_delivery_power_15m }}kW, estimated to be {{ electricity_delivery_power_15m_estimated }}kW with {{ minutes_remaining }}m remaining, current power {{ currently_delivered }}W, battery at {{battery}} ({{overdischargesoc}})%.
              '';
            };
          }
          (ha.action.delay "00:01:00")
        ];
        mode = "single";
      }
      {
        id = "electricity_delivery_power_max_threshold_light";
        alias = "electricity_delivery_power_max_threshold.light";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_max_threshold";
            to = "on";
          }
        ];
        condition = [];
        action = [
          {
            service = "light.turn_on";
            target.entity_id = "light.floor0_keuken_light_consumptionindicator";
            data = {
              rgb_color = [255 0 0];
              effect = "blink";
              transition = 10;
            };
          }
        ];
        mode = "single";
      }
      {
        id = "electricity_delivery_power_near_max_threshold_light";
        alias = "electricity_delivery_power_near_max_threshold.light";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_near_max_threshold";
            to = "on";
          }
        ];
        condition = [];
        action = [
          {
            service = "light.turn_on";
            target.entity_id = "light.floor0_keuken_light_consumptionindicator";
            data = {
              rgb_color = [255 200 0];
              effect = "blink";
              transition = 10;
            };
          }
        ];
        mode = "single";
      }
      {
        id = "electricity_delivery_power_normal_light";
        alias = "electricity_delivery_power_normal.light";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_near_max_threshold";
            to = "off";
          }
        ];
        condition = [];
        action = [
          {
            service = "light.turn_off";
            target.entity_id = "light.floor0_keuken_light_consumptionindicator";
          }
        ];
        mode = "single";
      }
      
    ];

  };
}
