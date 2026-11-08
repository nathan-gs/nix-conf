{ config, pkgs, lib, ha, ... }:

let

  autoWantedHeader = import ./temperature_sets.nix;
  rooms = import ../rooms.nix;

  # Inputs shared by heating_temperature_desired's state and its attributes,
  # so the explanation shown on the dashboard can't drift from the decision.
  desiredInputs = ''
    ${autoWantedHeader}
    {% set cv_temp = state_attr("climate.cv", "temperature") | float(15.5) %}
    {% set current_temp = state_attr("climate.cv", "current_temperature") | float(19.5) %}
    {% set temperature_diff_wanted = states("sensor.heating_temperature_diff_wanted") | float(0) %}
    {% set is_cv_water_circulating = is_state('binary_sensor.cv_water_circulating', 'on') %}
    {% set is_step_reached = current_temp >= cv_temp - 0.2 %}
    {% set max_desired_temp = 21 %}
    {% set target_temp = current_temp + temperature_diff_wanted %}
    {% set anyone_home_or_coming = is_state('binary_sensor.anyone_home_or_coming_home', 'on') %}
    {% set forecast_temp = states('sensor.weather_today_temperature_max') | float(15) %}
    {% set is_large_deviation_between_forecast_and_target = not ((forecast_temp + 2) >= target_temp and (forecast_temp - 3) <= target_temp) %}
    {% set is_heating_needed = is_state('binary_sensor.heating_use_gas', 'on') %}
    {% set short_threshold = temperature_heating_threshold + 0.1 %}
    {% set release_threshold = 0.15 %}
    {% set living_diff = states('sensor.floor0_living_temperature_diff_wanted') | float(0) %}
    {% set living_wanted = states('sensor.floor0_living_temperature_auto_wanted') | float(19.5) %}
    {# While the living room is on a real target, one step above it is enough
       for the other rooms. A bedroom that stays short must not walk the
       setpoint up to max_desired. Eco/night targets do not impose this cap. #}
    {% set step_ceiling = (living_wanted + 0.8) if living_wanted >= temperature_comfort_low else max_desired_temp %}
    {% set leading_diffs = [
      ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature_diff_wanted') | float(0)") rooms.heatedLeading)}
    ] %}
    {% set rooms_short = leading_diffs | select('>', short_threshold) | list | count %}
    {% set rooms_still = leading_diffs | select('>', release_threshold) | list | count %}
    {% set is_living_short = living_diff > short_threshold %}
    {% set is_one_room_cold = temperature_diff_wanted > 1.5 %}
    {% set is_gas_worth_it = is_living_short or rooms_short >= 2 or is_one_room_cold %}
    {# cv_temp above eco means a burn already started. Finish it: the analogue
       370 drops the loop the moment the setpoint falls to eco - 0.5, and the
       next call pays the warmup again. A single room under 0.5°C does not
       keep it, and a single room never starts one unless it is over 1.5°C. #}
    {% set burn_in_progress = cv_temp > temperature_eco %}
    {% set keep_burn = burn_in_progress and (living_diff > release_threshold or rooms_still >= 2 or temperature_diff_wanted > short_threshold) %}
    {% set call_gas = is_gas_worth_it or keep_burn %}
  '';

  # Own sensor, not an attribute: the CV dashboard row opens this entity's
  # history. An attribute click opens the parent temperature instead.
  # Electric words follow binary_sensor.heating_use_electric (vaillant.nix)
  # and the plug targets in electric_heating.nix. Surplus is a plug that is
  # on without that gate. Labels stay categorical so the history does not
  # track watts.
  decisionText = ''
    ${desiredInputs}
    {% set electric_on = is_state('binary_sensor.heating_use_electric', 'on') %}
    {% set enough_power = is_state('binary_sensor.electricity_delivery_power_near_max_threshold', 'off') %}
    {% set prefer_electricity = is_state('binary_sensor.energy_electricity_prefer_over_gas', 'on') %}
    {% set rooms_need = states('sensor.heating_number_of_rooms_in_need_of') | int(0) %}
    {% set bureau_short = states('sensor.floor0_bureau_temperature_diff_wanted') | float(0) > temperature_heating_threshold %}
    {% set nikolai_short = states('sensor.floor1_nikolai_temperature_diff_wanted') | float(0) > temperature_heating_threshold %}
    {% set solar_electric = states('sensor.system_house_pv_battery_soc') | float(10) > 32
      and states('sensor.energy_production_today_remaining') | float(0) > 6
      and states('sensor.electricity_grid_consumed_power_mean_1m') | float(1000) < 100 %}
    {% set electric_line = 'electric: solar' if electric_on and solar_electric else (
      'electric: bureau' if electric_on and bureau_short and not nikolai_short else (
      'electric: nikolai' if electric_on and nikolai_short and not bureau_short else (
      'electric: bureau+nikolai' if electric_on and bureau_short and nikolai_short else (
      'electric on' if electric_on else "")))) %}
    {% set living_on = is_state('binary_sensor.floor0_living_metering_plug_verwarming_target', 'on') %}
    {% set bureau_on = is_state('binary_sensor.floor0_bureau_metering_plug_verwarming_target', 'on') %}
    {% set nikolai_on = is_state('binary_sensor.floor1_nikolai_metering_plug_verwarming_target', 'on') %}
    {% set badkamer_on = is_state('binary_sensor.floor1_badkamer_metering_plug_verwarming_target', 'on') %}
    {% set living_note = "" if (not living_on) or ('living' in electric_line) else ('living' if electric_on and solar_electric else 'living surplus') %}
    {% set bureau_note = "" if (not bureau_on) or ('bureau' in electric_line) else ('bureau' if electric_on and solar_electric else 'bureau surplus') %}
    {% set nikolai_note = "" if (not nikolai_on) or ('nikolai' in electric_line) else ('nikolai' if electric_on and solar_electric else 'nikolai surplus') %}
    {% set badkamer_note = "" if (not badkamer_on) or ('bathroom' in electric_line) else 'bathroom' %}
    {% set capacity_note = 'electric blocked, capacity' if (
      not electric_on and not enough_power and prefer_electricity and anyone_home_or_coming
      and rooms_need == 1 and (bureau_short or nikolai_short)
    ) else "" %}
    {% set far_note = 'capped: coming from far' if coming_home_from_far else "" %}
    {% set suffix = [far_note, living_note, bureau_note, nikolai_note, badkamer_note, capacity_note] | select('!=', "") | join(', ') %}
    {%- if not anyone_home_or_coming -%}
      {{ 'far away' if far_away else 'away' }}
    {%- elif not is_heating_needed -%}
      {{ electric_line if electric_line != "" else 'no heat needed' }}
    {%- elif not call_gas -%}
      {{ 'single room waits' if rooms_short == 1 else 'no room short' }}
    {%- elif not is_large_deviation_between_forecast_and_target -%}
      mild forecast
    {%- elif is_cv_water_circulating and not is_step_reached -%}
      holding step
    {%- elif keep_burn and not is_gas_worth_it -%}
      finishing burn
    {%- else -%}
      heating: {{ 'living' if is_living_short else ('2+ rooms' if rooms_short >= 2 else 'one room cold') }}
    {%- endif -%}
    {%- if suffix != "" %} · {{ suffix }}{% endif -%}
  '';

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
            # (this setpoint - living room temperature).
            #  - heating: at most +0.8 above the living room, so flow stays low
            #    and burns soft. Each step is held while the CV water circulates,
            #    including when the deficit is over 1°C. Skipping that hold on a
            #    large deficit (the morning climb from ~17°C back to 19.5) kept
            #    a full 0.8 gap the whole way up, and the 370 answered with
            #    65-85°C flow. The hold still ends once the living room is
            #    within 0.2 of the step, then the next +0.8 is allowed, so a
            #    cold start climbs in a few soft steps instead of one chase.
            #    Under analogue control the pump can keep running at low
            #    modulation, which is why the hold ends on that 0.2 gap, about
            #    where a two-point 370 stopped it;
            #  - not heating: straight down to eco - 0.5. A small negative gap
            #    does NOT switch an analogue 370 off: with the setpoint held
            #    0.5-1.0 under the room (2026-10-19/20) it kept asking 26-33°C
            #    flow, fired every 40-60 min and held the house at ~19°C all
            #    night, ~0.9-1.2 m3/night against ~0.1 for spring 2026 nights at
            #    the same outdoor temperature. It holds the room roughly 0.6-1.1
            #    above the setpoint, hence the -0.5 to land near eco/night.
            #
            # Gas only starts for the living room, for two or more leading rooms,
            # or for one room that is really cold. In winter 2025/26 45% of
            # heating gas was burned with a single room short, mostly bureau,
            # fen or nikolai on their own; those wait for company (bureau and
            # nikolai still get their electric heaters, see heating_use_electric).
            # A burn that has already started keeps going until those rooms are
            # back within 0.15°C (two of them, or the living room) or the
            # coldest is back under the 0.5°C start threshold. 23 Oct 2026
            # dropped the setpoint to 15.0 three times during the afternoon
            # and paid 0.2-0.4 m³ to start again each time. Comfort stays 19.5.
            state = ''
              ${desiredInputs}
              {% if anyone_home_or_coming %}
                {% if call_gas and is_heating_needed and is_large_deviation_between_forecast_and_target %}
                  {% if is_cv_water_circulating and not is_step_reached %}
                    {# Hold the step: let the rooms heat up. #}
                    {% set new_temp = min(cv_temp, target_temp, step_ceiling) %}
                    {% set new_temp = (new_temp * 2) | round(0) / 2 %}
                  {% else %}
                    {% set new_temp = min(current_temp + 0.8, max_desired_temp, target_temp, step_ceiling) %}
                    {% set new_temp = (new_temp * 2) | round(0) / 2 %}
                  {% endif %}
                {% else %}
                  {# Off: low enough that the analogue 370 stops heating #}
                  {% set new_temp = temperature_eco - 0.5 %}
                {% endif %}
                {# coming_home while still far from home: preheat, but no
                   further than away temperature. #}
                {% if coming_home_from_far %}
                  {% set new_temp = min(new_temp, temperature_away) %}
                {% endif %}
              {% elif far_away %}
                {% set new_temp = temperature_minimal %}
              {% else %}
                {% set new_temp = temperature_away %}
              {% endif %}
              {{ new_temp }}
            '';
            attributes.rooms_short = ''
              ${desiredInputs}
              {{ rooms_short }}
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
          {
            name = "heating_decision";
            unique_id = "heating_decision";
            state = decisionText;
            icon = "mdi:comment-text-outline";
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
        # Far away: put the 370 in holiday mode, which takes both the heating
        # circuit (frost protection) and the hot water off. Only the holiday
        # dates are writable over ebus -- Hc1SFMode and HwcOPMode are
        # read-only and follow from them -- so the period is re-armed as
        # today .. today+7 every night and the holiday never runs out while
        # we're gone. End is written first so start never lands after it.
        id = "cv_holiday_far_away";
        alias = "cv.holiday_far_away";
        trigger = [
          (ha.trigger.on "binary_sensor.far_away")
          (ha.trigger.at "00:05:00")
          { platform = "homeassistant"; event = "start"; }
        ];
        condition = [
          (ha.condition.state "binary_sensor.far_away" "on")
        ];
        action = [
          # HDA:3 -> dd.mm.yyyy
          (ha.action.mqtt_publish "ebusd/370/Hc1HolidayEndPeriod/set" "{{ (now() + timedelta(days=7)).strftime('%d.%m.%Y') }}" false)
          (ha.action.delay "0:00:05")
          (ha.action.mqtt_publish "ebusd/370/Hc1HolidayStartPeriod/set" "{{ now().strftime('%d.%m.%Y') }}" false)
        ];
        mode = "single";
      }
      {
        # Back from far away (coming_home, or simply back within range): end
        # the holiday by moving the whole period to yesterday. The end date is
        # inclusive, so ending it "today" would keep the 370 on frost
        # protection until midnight. Only on a real on -> off, so an HA restart
        # never rewrites a holiday that was set by hand on the 370.
        id = "cv_holiday_end";
        alias = "cv.holiday_end";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.far_away";
            from = "on";
            to = "off";
          }
        ];
        action = [
          (ha.action.mqtt_publish "ebusd/370/Hc1HolidayStartPeriod/set" "{{ (now() - timedelta(days=1)).strftime('%d.%m.%Y') }}" false)
          (ha.action.delay "0:00:05")
          (ha.action.mqtt_publish "ebusd/370/Hc1HolidayEndPeriod/set" "{{ (now() - timedelta(days=1)).strftime('%d.%m.%Y') }}" false)
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
