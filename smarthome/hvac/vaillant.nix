{ config, pkgs, lib, ha, ... }:

let

  autoWantedHeader = import ./temperature_sets.nix;

in
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
          {
            name = "heating_temperature_diff_wanted";
            unit_of_measurement = "°C";
            device_class = "temperature";
            state = ''
              {% set nikolai_not_home_alone = not(states('binary_sensor.occupancy_home_alone_nikolai_in_use') | bool(false)) %}
              {% set bureau_not_home_alone = not(states('binary_sensor.occupancy_home_alone_bureau_in_use') | bool(false)) %}
              {% set nikolai_temp = states('sensor.floor1_nikolai_temperature_diff_wanted') if nikolai_not_home_alone else "ignore" %}
              {% set bureau_temp = states('sensor.floor0_bureau_temperature_diff_wanted') if bureau_not_home_alone else "ignore" %}
              {% 
              set v = (
                states('sensor.floor0_living_temperature_diff_wanted'),
                states('sensor.floor1_fen_temperature_diff_wanted'),
                states('sensor.floor1_morgane_temperature_diff_wanted'),
                nikolai_temp,
                bureau_temp
              )
              %}
              {% set valid_temp = v | select('!=', "ignore") | select('!=','unknown') | map('float') | list %}
              {{ max(valid_temp) | round(2) }}
            '';
            icon = "mdi:thermometer-auto";
            state_class = "measurement";
          }
          {
            name = "heating_temperature_desired";
            unit_of_measurement = "°C";
            device_class = "temperature";
            state = ''
              ${autoWantedHeader}
              {% set cv_temp = state_attr("climate.cv", "temperature") | float(15.5) %}
              {% set current_temp = state_attr("climate.cv", "current_temperature") | float(19.5) %}
              {% set temperature_diff_wanted = states("sensor.heating_temperature_diff_wanted") | float(0) %}
              {% set max_desired_temp = 21 %}
              {% set target_temp = current_temp + temperature_diff_wanted %}
              {% set new_temp = cv_temp %}
              {% set is_anyone_home_or_coming = is_state('binary_sensor.anyone_home_or_coming_home', 'on') %}
              {% set is_travelling = is_state('binary_sensor.far_away', 'on') %}
              {% set forecast_temp = states('sensor.openweathermap_forecast_temperature') | float(15) %}
              {% set is_large_deviation_between_forecast_and_target = not ((forecast_temp + 2) >= target_temp and (forecast_temp - 3) <= target_temp) %}
              {% set is_heating_needed = target_temp > current_temp %}
              {% set is_cv_water_circulating = is_state('binary_sensor.cv_water_circulating', 'on') %}
              {% set is_sufficient_increase = temperature_diff_wanted > 0.4 %}
              {% if is_anyone_home_or_coming %}
                {% if is_sufficient_increase and is_heating_needed and is_large_deviation_between_forecast_and_target %}
                  {% if is_cv_water_circulating %}
                    {# Do nothing #}
                    {% set new_temp = cv_temp %}
                  {% else %}
                    {# Gradually increase temperature #}
                    {% set new_temp = (current_temp + 0.6) %}
                    {% set new_temp = min(new_temp, max_desired_temp, target_temp) %}
                  {% endif %}
                {% else %}          
                  {% set new_temp = (target_temp - 0.5) %}
                  {% set new_temp = max(new_temp, temperature_eco) %}
                {% endif %}
              {% elif is_travelling %}
                {% set new_temp = temperature_minimal %}
              {% else %}
                {% set new_temp = temperature_away %}
              {% endif %}
              {% set new_temp = ((new_temp * 2) | round(0) / 2) %}
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
            state = ''{{ is_state('sensor.ebusd_bai_status01_pumpstate', "on")}}'';
            delay_off.minutes = 1;
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
          (ha.action.mqttPublish "ebusd/370/DisplayedHc1RoomTempDesired/get" "?1" false)
          (ha.action.delay "0:00:05")
          (ha.action.mqttPublish "ebusd/370/Hc1DayTemp/get" "?1" false)
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
          map (x: (ha.action.mqttPublish "${x}/get" "?3" false)) [
            "ebusd/370/DisplayedHc1RoomTempDesired"
            "ebusd/370/DisplayedRoomTemp"
            "ebusd/bai/FlowTemp"
            "ebusd/bai/FlowTempDesired"
            "ebusd/bai/ReturnTemp"
            "ebusd/bai/ModulationTempDesired"
          ]
          ++ [
            (ha.action.delay "0:00:05")
          ];
        mode = "queued";
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
        temperature_state_template = "{{ value_json.temp1.value }}";
        temperature_low_state_topic = "ebusd/370/Hc1NightTemp";
        temperature_low_state_template = "{{ value_json.temp1.value }}";
        temperature_high_state_topic = "ebusd/370/Hc1DayTemp";
        temperature_high_state_template = "{{ value_json.temp1.value }}";
        temperature_low_command_topic = "ebusd/370/Hc1NightTemp/set";
        temperature_low_command_template = ''
          {{ value }}
        '';
        temperature_high_command_topic = "ebusd/370/Hc1DayTemp/set";
        temperature_high_command_template = ''
          {{ value }}
        '';
        current_temperature_topic = "ebusd/370/DisplayedRoomTemp";
        current_temperature_template = "{{ value_json.temp.value }}";
        temperature_unit = "C";
      }
      {
        name = "boiler";
        max_temp = 90;
        min_temp = 0;
        precision = 0.1;
        temp_step = 0.5;
        # unfortunately mapping is not correct (Yet)
        modes = [ "off" "on" "auto" "party" "load" "holiday" ];
        mode_state_template = ''
          {% set values = { 0:'off', 1:'on',  2:'auto', 3:'autosunday', 4:'party', 5: 'load', 7: 'holiday'} %}
          {{ values[value] if value in values.keys() else 'auto' }}
        '';
        mode_state_topic = "ebusd/370/HwcOPMode";
        mode_command_template = ''
          {% set values = { 'off':0, 'on':1,  'auto':2, 'autosunday':3, 'party':4, 'load':5, 'holiday':7} %}
          {{ values[value] if value in values.keys() else 2 }}
        '';
        mode_command_topic = "ebusd/370/HwcOPMode/set";
        temperature_state_topic = "ebusd/370/HwcTempDesired";
        temperature_state_template = "{{ value_json.temp1.value }}";
        current_temperature_topic = "ebusd/370/DisplayedHwcStorageTemp";
        current_temperature_template = "{{ value_json.temp1.value }}";
        temperature_unit = "C";
      }
    ];

    recorder = {
       include = {
        entities = [
          "climate.cv"
          "climate.boiler"
        ];
        entity_globs = [
          "sensor.cv_*"
          "sensor.heating_*"
          "sensor.itho_wtw_outlet_*"
          "binary_sensor.ebusd_*"
          "sensor.ebusd_*"
        ];

      };
      exclude = {
        entities = [
          "sensor.ebusd_uptime"
          "device_tracker.ebus"
          "switch.ebus_internet_access"
          "automation.cv_query"
          "automation.cv_temperature_set"
          "update.ebusd_updatecheck"
          "binary_sensor.ebusd_370_chimneysweepmodeactive_yesno"
          "sensor.ebusd_370_adcvaluetempbelow"
          "sensor.ebusd_370_b51000m7opmodemonitor"
          "sensor.ebusd_370_b51000tempdesiredloadingpump"
          "sensor.ebusd_bai_hchours_hoursum2"
          "sensor.ebusd_bai_hcpumpstarts_cntstarts2"
          "sensor.ebusd_bai_hcstarts"
          "sensor.ebusd_bai_hcunderhundredstarts"
          "sensor.ebusd_bai_hourstillservice_hoursum2"
          "sensor.ebusd_bai_hwchours_hoursum2"
          "sensor.ebusd_bai_hwcstarts"
          "sensor.ebusd_bai_hwcunderhundredstarts"
          "sensor.ebusd_bai_prapscounter"
          "sensor.ebusd_bai_prvortexflowsensorvalue"
          "sensor.ebusd_bai_pumphours_hoursum2"
          "sensor.ebusd_bai_returntemp_tempmirror"
          "sensor.ebusd_bai_setmode_hwcflowtempdesired"
          "sensor.ebusd_bai_setmode_releasebackup"
          "sensor.ebusd_bai_setmode_releasecooling"
          "sensor.ebusd_bai_setmode_remotecontrolhcpump"
          "sensor.ebusd_bai_shemaxflowtemp_temp"
          "sensor.ebusd_bai_status01_temp1_3"
          "sensor.ebusd_bai_status01_temp2"
          "sensor.ebusd_bai_status16_temp"
          "sensor.ebusd_bai_status_hcmode2"
          "sensor.ebusd_bai_status_press_2"
          "sensor.ebusd_bai_status_temp"
          "sensor.ebusd_bai_storageloadpumphours_hoursum2"
          "sensor.ebusd_bai_storageloadpumpstarts_cntstarts2"
          "sensor.ebusd_bai_valvestarts_cntstarts2"
          "sensor.ebusd_bai_vortexflowsensor"
          "sensor.ebusd_scan"
          "binary_sensor.ebusd_370_chimneysweepmodeactive_yesno"
          "binary_sensor.ebusd_bai_timerinputhc_onoff"
        ];
        entity_globs = [
          "sensor.ebusd_bai_prenergycounthc*"
          "sensor.ebusd_bai_prenergycounthwc*"
          "sensor.ebusd_bai_prenergysumhc*"
          "sensor.ebusd_bai_prenergysumhwc*"
          "sensor.ebusd_bai_counterstartattempts1_temp*"
          "sensor.ebusd_370_cctimer_*"
          "sensor.ebusd_370_hctimer_*"
          "sensor.ebusd_370_hwctimer_*"
        ];
      };
    };
  };

}
