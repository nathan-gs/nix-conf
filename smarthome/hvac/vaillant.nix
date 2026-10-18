{ config, pkgs, lib, ha, ... }:

let

  autoWantedHeader = import ./temperature_sets.nix;
  rooms = import ../rooms.nix;

in
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
          {
            name = "heating_temperature_diff_wanted";
            unique_id = "heating_temperature_diff_wanted";
            unit_of_measurement = "°C";
            device_class = "temperature";
            state = ''
              {% set v = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature_diff_wanted')") rooms.heatedLeading)}
              ]
              %}  
              {% set valid_temp = v | select('!=', "ignore") | select('!=','unknown') | map('float') | list %}
              {{ max(valid_temp) | round(2) }}
            '';
            icon = "mdi:thermometer-auto";
            state_class = "measurement";
          }
          {
            name = "heating/number_of_rooms_in_need_of";
            unique_id = "heating_number_of_rooms_in_need_of";
            state = ''
              ${autoWantedHeader}
              {% set v = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature_diff_wanted')") rooms.heated)}
              ]
              %}
              {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
              {{ valid_v | select('>', temperature_heating_threshold) | list | count }}
            '';
            icon = "mdi:thermometer-auto";
            state_class = "measurement";
          }                    
          {
            name = "heating_temperature_desired";
            unique_id = "heating_temperature_desired";
            unit_of_measurement = "°C";
            device_class = "temperature";
            # The 370 runs in analogue control: it sets the flow temperature from
            # (this setpoint - living room temperature). So the setpoint is only
            # ever a small step either side of the living room:
            #  - heating: at most +0.8 above it, so flow stays low and burns soft.
            #    Each step is held while the CV water circulates, so the other
            #    rooms get time to heat up before the next push. Under analogue
            #    control the pump can keep running at low modulation, so the
            #    hold also ends once the living room is within 0.2 of the step,
            #    which is about where a two-point 370 used to stop the pump;
            #  - not heating: 0.5-1.0 below it, so the 370 simply stays off.
            # It used to walk down 0.5 per controller read-back to eco, which
            # dropped 19.5 -> 15.5 within minutes and swung the full range in
            # most heating hours of winter 2025/26 -- on/off control on top of
            # the 370's modulation.
            #
            # Gas only runs for the living room, for two or more leading rooms,
            # or for one room that is really cold. In winter 2025/26 45% of
            # heating gas was burned with a single room short, mostly bureau,
            # fen or nikolai on their own; those wait for company (bureau and
            # nikolai still get their electric heaters, see heating_use_electric).
            state = ''
              ${autoWantedHeader}
              {% set cv_temp = state_attr("climate.cv", "temperature") | float(15.5) %}
              {% set current_temp = state_attr("climate.cv", "current_temperature") | float(19.5) %}
              {% set temperature_diff_wanted = states("sensor.heating_temperature_diff_wanted") | float(0) %}
              {% set is_cv_water_circulating = is_state('binary_sensor.cv_water_circulating', 'on') %}
              {% set is_large_increase_needed = temperature_diff_wanted > 1 %}
              {% set is_step_reached = current_temp >= cv_temp - 0.2 %}
              {% set max_desired_temp = 21 %}
              {% set target_temp = current_temp + temperature_diff_wanted %}
              {% set anyone_home_or_coming = is_state('binary_sensor.anyone_home_or_coming_home', 'on') %}
              {% set forecast_temp = states('sensor.weather_today_temperature_max') | float(15) %}
              {% set is_large_deviation_between_forecast_and_target = not ((forecast_temp + 2) >= target_temp and (forecast_temp - 3) <= target_temp) %}
              {% set is_heating_needed = is_state('binary_sensor.heating_use_gas', 'on') %}
              {% set short_threshold = temperature_heating_threshold + 0.1 %}
              {% set leading_diffs = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature_diff_wanted') | float(0)") rooms.heatedLeading)}
              ] %}
              {% set rooms_short = leading_diffs | select('>', short_threshold) | list | count %}
              {% set is_living_short = states('sensor.floor0_living_temperature_diff_wanted') | float(0) > short_threshold %}
              {% set is_one_room_cold = temperature_diff_wanted > 1.5 %}
              {% set is_gas_worth_it = is_living_short or rooms_short >= 2 or is_one_room_cold %}
              {% if anyone_home_or_coming %}
                {% if is_gas_worth_it and is_heating_needed and is_large_deviation_between_forecast_and_target %}
                  {% if is_cv_water_circulating and not is_large_increase_needed and not is_step_reached %}
                    {# Hold the step: let the rooms heat up #}
                    {% set new_temp = min(cv_temp, target_temp) %}
                    {% set new_temp = (new_temp * 2) | round(0) / 2 %}
                  {% else %}
                    {# Gradually increase temperature #}
                    {% set new_temp = min(current_temp + 0.8, max_desired_temp, target_temp) %}
                    {% set new_temp = (new_temp * 2) | round(0) / 2 %}
                  {% endif %}
                {% else %}
                  {# Just below the room, rounded down: 0.5-1.0 under it #}
                  {% set new_temp = ((current_temp - 0.5) * 2) | round(0, 'floor') / 2 %}
                  {% set new_temp = max(new_temp, temperature_eco) %}
                {% endif %}
              {% elif far_away %}
                {% set new_temp = temperature_minimal %}
              {% else %}
                {% set new_temp = temperature_away %}
              {% endif %}
              {{ new_temp }}
            '';
            icon = ''
              {% if (state_attr("climate.cv", "current_temperature") | float(19.5)) < (states('sensor.heating_temperature_desired') | float(19.5)) %}
                mdi:thermometer-chevron-up
              {% else %}
                mdi:thermometer-chevron-down
              {% endif %}
            '';
            state_class = "measurement";            
          }
        ];
        binary_sensor = [
          {
            name = "cv/water_circulating";
            unique_id = "cv_water_circulating";
            state = ''{{ is_state('sensor.ebusd_bai_status01_pumpstate', "on")}}'';
            delay_off.minutes = 1;
            device_class = "running";
          }
          {
            name = "heating/use_electric";
            unique_id = "heating_use_electric";
            state = ''
              ${autoWantedHeader}
              {% set rooms_need_heating = states('sensor.heating_number_of_rooms_in_need_of') | int(0) %}
              {% set prefer_electricity = is_state('binary_sensor.energy_electricity_prefer_over_gas', 'on') %}
              {% set enough_power = is_state('binary_sensor.electricity_delivery_power_near_max_threshold', 'off') %}
              {% set just_1room = rooms_need_heating == 1 %}
              {% set is_anyone_home_or_coming = is_state('binary_sensor.anyone_home_or_coming_home', 'on') %}
              {% set is_bureau = states('sensor.floor0_bureau_temperature_diff_wanted') | float(0) > temperature_heating_threshold %}
              {% set is_nikolai = states('sensor.floor1_nikolai_temperature_diff_wanted') | float(0) > temperature_heating_threshold %}
              {% set is_battery_charged = states('sensor.system_house_pv_battery_soc') | float(10) > 32 %}
              {% set is_not_using_grid = states('sensor.electricity_grid_consumed_power_mean_1m') | float(1000) < 100 %}
              {% set is_solar = states('sensor.electricity_solar_power') | float(0) > 300 %}
              {% set is_solar_remaining = states('sensor.energy_production_today_remaining') | float(0) > 6 %}
              {% set use_solar_and_battery = is_battery_charged and is_solar_remaining and is_not_using_grid %}
              {% if enough_power and is_anyone_home_or_coming %}
                {% if use_solar_and_battery %}
                  {{ rooms_need_heating >= 1 }}
                {% else %}
                  {{ just_1room and prefer_electricity and (is_bureau or is_nikolai) }}
                {% endif %}
              {% else %}
                false
              {% endif %}
            '';
            device_class = "running";
          }
          {
            name = "heating/use_gas";
            unique_id = "heating_use_gas";
            state = ''
              {% set temperature_diff_wanted = states("sensor.heating_temperature_diff_wanted") | float(0) %}
              {% set use_electric = is_state('binary_sensor.heating_use_electric', 'on') %}
              {% set current_temp = state_attr("climate.cv", "current_temperature") | float(19.5) %}
              {% set target_temp = current_temp + temperature_diff_wanted %}
              {% set is_anyone_home_or_coming = is_state('binary_sensor.anyone_home_or_coming_home', 'on') %}
              {% set is_heating_needed = target_temp > current_temp %}
              {{ not(use_electric) and is_heating_needed }}
            '';
            device_class = "running";
            delay_on = "00:00:15";
          }
        ];
      }

    ];

    "automation manual" = [
      {
        id = "cv_temperature_set";
        alias = "cv.temperature_set";
        trigger = [
          (ha.trigger.state "sensor.heating_temperature_desired")
          # Re-enabling heating does not change the desired temperature, and the
          # mode condition below blocks every push made while it was off, so
          # without this the controller keeps its stale setpoint until the
          # desired temperature happens to move again.
          (ha.trigger.state_to "climate.cv" "heat")
        ];
        condition = [
          (ha.condition.state "climate.cv" "heat")
        ];
        action = [
          {
            service = "climate.set_temperature";
            target.entity_id = "climate.cv";
            data = {
              target_temp_high = "{{ states('sensor.heating_temperature_desired') | float(15.5) }}";
              target_temp_low = "10";
            };
          }
          (ha.action.delay "0:00:15")
          # Workaround to update desired temperature
          (ha.action.mqtt_publish "ebusd/370/DisplayedHc1RoomTempDesired/get" "?1" false)
          (ha.action.delay "0:00:05")
          (ha.action.mqtt_publish "ebusd/370/Hc1DayTemp/get" "?1" false)
          (ha.action.delay "0:00:05")
        ];
        mode = "queued";
      }
      {
        id = "cv_query";
        alias = "cv.query";
        trigger = [
          {
            platform = "time_pattern";
            minutes = "/5";
          }
        ];
        action =
          map (x: (ha.action.mqtt_publish "${x}/get" "?3" false)) [
            "ebusd/370/DisplayedHc1RoomTempDesired"
            "ebusd/370/DisplayedRoomTemp"
            "ebusd/370/Hc1OPMode"
            "ebusd/370/Hc1DayTemp"
            "ebusd/bai/FlowTemp"
            "ebusd/bai/FlowTempDesired"
            "ebusd/bai/ReturnTemp"
            # bai.308523.inc (HW7401) names this ModulationDesired, not
            # ModulationTempDesired (HA ebusd const.py / older CSVs).
            "ebusd/bai/ModulationDesired"
            "ebusd/bai/WaterPressure"
            "ebusd/bai/Flame"
            "ebusd/bai/WP"
            "ebusd/bai/Status01"
          ]
          ++ [
            (ha.action.delay "0:00:05")
          ];
        mode = "queued";
      }
      {
        # The calorMATIC 370 has no radio clock: `bai DateTime` reads
        # "nosignal" and the DCF registers are deliberately not polled (see
        # services/ebusd.nix), so its RTC free-runs and drifts. Nothing else on
        # the bus corrects it -- the boiler takes its time *from* the
        # controller, not the other way round -- so left alone it slowly walks
        # away from real time, which silently shifts the heating schedule, the
        # legionella start slot (HwcLegioStartDay/Time) and StoragereleaseClock.
        #
        # nhtpc is NTP-synced, so HA is the accurate clock here. Both registers
        # have a `w` row at access level "" in vaillant/15.370.csv (Date =
        # b509/0e6100 HDA:3, Time = b509/0e6000 VTI), so no installer code is
        # needed -- the same /set path the climate entities already use.
        #
        # Date is written before Time: the controller derives ActualWeekday
        # from the date, and the weekday is what the schedules key off. Time
        # goes last so the most precision-sensitive value is the freshest.
        #
        # Every 6h rather than daily so a DST jump is corrected within a few
        # hours instead of being visible until the next night, and so drift
        # stays in the seconds. Offset to :07 to stay clear of the on-the-hour
        # cv.query poll burst above.
        id = "cv_sync_clock";
        alias = "cv.sync_clock";
        trigger = [
          {
            platform = "time_pattern";
            hours = "/6";
            minutes = "7";
          }
        ];
        action = [
          # HDA:3 -> dd.mm.yyyy. now() is local time, so DST is handled.
          (ha.action.mqtt_publish "ebusd/370/Date/set" "{{ now().strftime('%d.%m.%Y') }}" false)
          (ha.action.delay "0:00:05")
          # VTI -> HH:MM:SS
          (ha.action.mqtt_publish "ebusd/370/Time/set" "{{ now().strftime('%H:%M:%S') }}" false)
        ];
        mode = "single";
      }
      {
        # Vaillant ecoTEC boilers warn on the display below ~1.0 bar and lock
        # out (F.22/F.75-style fault) around 0.7-0.8 bar. Warn early so it can
        # be topped up before the boiler actually faults.
        id = "cv_water_pressure_low";
        alias = "cv.water_pressure_low";
        trigger = [
          (ha.trigger.below_for "sensor.heating_ebusd_bai_waterpressure_press" 1.0 "0:30:00")
        ];
        condition = [ ];
        action = [
          (ha.action.notify "CV waterdruk laag"
            ''
              CV waterdruk is {{ states('sensor.heating_ebusd_bai_waterpressure_press') }} bar (al 30 min onder 1.0 bar).
              Bijvullen voordat de ketel op storing gaat (meestal rond 0.7-0.8 bar).
            '')
        ];
        mode = "single";
      }
    ];

    # https://fromeijn.nl/connected-vaillant-to-home-assistant/
    mqtt.climate = [
      {
        name = "CV";
        max_temp = 25;
        min_temp = 5.5;
        precision = 0.1;
        temp_step = 0.5;
        modes = [ "auto" "heat" "cool" "off" ];
        # Quite an ugly regex workaround due to 0 not being findable...
        mode_state_template = ''
          {% set values = { 'auto':'auto', 'on':'heat',  'night':'cool', 'summer':'off'} %}
          {% set v = value | regex_findall_index( '"value"\s?:\s?"(.*)"')  %}
          {{ values[v] if v in values.keys() else 'auto' }}
        '';
        mode_state_topic = "ebusd/370/Hc1OPMode";
        mode_command_template = ''
          {% set values = { 'auto':'auto', 'heat':'on',  'cool':'night', 'off':'summer'} %}
          {{ values[value] if value in values.keys() else 'off' }}
        '';
        mode_command_topic = "ebusd/370/Hc1OPMode/set";
        temperature_state_topic = "ebusd/370/DisplayedHc1RoomTempDesired";
        temperature_state_template = "{{ value_json.value.value }}";
        temperature_low_state_topic = "ebusd/370/Hc1NightTemp";
        temperature_low_state_template = "{{ value_json.value.value }}";
        temperature_high_state_topic = "ebusd/370/Hc1DayTemp";
        temperature_high_state_template = "{{ value_json.value.value }}";
        temperature_low_command_topic = "ebusd/370/Hc1NightTemp/set";
        temperature_low_command_template = ''
          {{ value }}
        '';
        temperature_high_command_topic = "ebusd/370/Hc1DayTemp/set";
        temperature_high_command_template = ''
          {{ value }}
        '';
        current_temperature_topic = "ebusd/370/DisplayedRoomTemp";
        current_temperature_template = "{{ value_json.value.value }}";
        temperature_unit = "C";
      }
      {
        name = "boiler";
        # 370 DHW setpoint range.
        max_temp = 70;
        min_temp = 35;
        precision = 0.1;
        temp_step = 0.5;
        # HwcOPMode is read-only on the 370 (15.370.csv has no `w` row; the
        # mode is "set implicitly" from the controller's own menu), so there is
        # no mode command. Its raw values are not HA HVAC modes, so they are
        # folded onto off/heat/auto here and the exact name is kept as the
        # `dhw_mode` attribute.
        modes = [ "off" "heat" "auto" ];
        mode_state_topic = "ebusd/370/HwcOPMode";
        mode_state_template = ''
          {% set values = { 0:'off', 1:'heat', 2:'auto', 3:'auto', 4:'heat', 6:'heat', 7:'off' } %}
          {% set v = value_json.value.value | int(-1) %}
          {{ values[v] if v in values else 'auto' }}
        '';
        json_attributes_topic = "ebusd/370/HwcOPMode";
        json_attributes_template = ''
          {% set names = { 0:'off', 1:'on', 2:'auto', 3:'auto_sunday', 4:'party', 6:'one_time_tank_loading', 7:'holiday' } %}
          {% set v = value_json.value.value | int(-1) %}
          {{ { 'dhw_mode': names[v] if v in names else 'unknown' } | tojson }}
        '';
        temperature_state_topic = "ebusd/370/HwcTempDesired";
        temperature_state_template = "{{ value_json.value.value }}";
        # HwcTempDesired is writable at user level. Effective DHW temperature is
        # still capped by the boiler's front knob.
        temperature_command_topic = "ebusd/370/HwcTempDesired/set";
        current_temperature_topic = "ebusd/370/DisplayedHwcStorageTemp";
        current_temperature_template = "{{ value_json.value.value }}";
        temperature_unit = "C";
      }
    ];

  };

}
