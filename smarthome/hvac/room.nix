{ config, pkgs, lib, ha, ... }:

let
  rooms = import ../rooms.nix;
  temperatureHeader = import ./temperature_sets.nix;

  heatedRooms = rooms.heated;

  temperatureSets = content: ''
    ${temperatureHeader}
    ${content}
  '';

  windowClosed = sensor: left: ''
    {% set is_window_closed = states('${sensor}') | bool(false) == false %}
    {% if is_window_closed %}
      ${left}
    {% else %}
      {{ temperature_minimal }}
    {% endif %}
  '';

  inUse = sensor: right: ''
    {% set in_use = states('${sensor}') | bool(false) %}
    {% if in_use %}
      {{ temperature_comfort }}
    {% else %}
      ${right}
    {% endif %}
  '';

  inUseBeforeNight = sensor: right: ''
    {% set in_use = states('${sensor}') | bool(false) %}
    {% if in_use and now().hour >= 7 and now().hour < 22 %}
      {{ temperature_comfort }}
    {% else %}
      ${right}
    {% endif %}
  '';

  inUseDuringWorkingHours = sensor: right: ''
    {% set in_use = states('${sensor}') | bool(false) %}
    {% if in_use and now().hour < 17 %}
      {{ temperature_comfort }}
    {% else %}
      ${right}
    {% endif %}
  '';

  workday = left: right: ''
    {% if workday %}
      ${left}
    {% else %}
      ${right}
    {% endif %}
  '';

  kidsRoomWorkdayTemperature = ''
    {% if now().hour >= 6 and now().hour < 18 %}
      {{ temperature_eco }}
    {% elif now().hour >= 18 and now().hour < 22 %}
      {{ temperature_comfort_low }}
    {% else %}
      {{ temperature_night }}
    {% endif %}
  '';

  kidsRoomWeekendTemperature = ''
    {% if now().hour >= 7 and now().hour < 9 %}
      {{ temperature_eco }}
    {% elif now().hour >= 9 and now().hour < 18 %}
      {% if anyone_home %}
        {{ temperature_comfort_low }}
      {% else %}
        {{ temperature_night }}
      {% endif %}
    {% elif now().hour >= 18 and now().hour < 22 %}
      {{ temperature_comfort_low }}
    {% else %}
      {{ temperature_night }}
    {% endif %}
  '';

  templateSensorTemperature = ha.sensor.temperature;

  roomTempFunction = { floor, room, sensors, adjustment ? 0 }: {
    name = "${floor}/${room}/temperature";
    state = ''
      {% set v = [
        ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}')") sensors)}
      ]
      %}
      {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
      {{ ((valid_v | sum / valid_v | length) | round(2) + ${toString adjustment}) }}
    '';
    unit_of_measurement = "°C";
    device_class = "temperature";
    state_class = "measurement";    
  };

  roomHumidityFunction = { floor, room, sensors, adjustment ? 0 }: {
    name = "${floor}/${room}/humidity";
    state = ''
      {% set v = [
        ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}')") sensors)}
      ]
      %}
      {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
      {{ ((valid_v | sum / valid_v | length) | round(2) + ${toString adjustment}) }}
    '';
    unit_of_measurement = "%";
    device_class = "humidity";
    state_class = "measurement";    
  };

in
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
          (
            templateSensorTemperature "floor1/nikolai/temperature_auto_wanted" (
              temperatureSets
                (windowClosed
                  "binary_sensor.floor1_nikolai_window_na_contact"
                  (workday
                    (inUseDuringWorkingHours
                      "input_boolean.floor1_nikolai_in_use"
                      (kidsRoomWorkdayTemperature))
                    (kidsRoomWeekendTemperature)
                  )
                )
            )
          )
          (
            templateSensorTemperature "floor1/morgane/temperature_auto_wanted" (
              temperatureSets
                (windowClosed
                  "binary_sensor.floor1_morgane_window_na_contact"
                  (workday
                    (kidsRoomWorkdayTemperature)
                    (kidsRoomWeekendTemperature)
                  )
                )
            )
          )
          (
            templateSensorTemperature "floor1/fen/temperature_auto_wanted" (
              temperatureSets
                (windowClosed
                  "binary_sensor.floor1_fen_window_na_contact"
                  ''
                    {% if now().hour >= 6 and now().hour < 18 %}
                      {{ temperature_eco }}
                    {% else %}
                      {{ temperature_night }} 
                    {% endif %}
                  ''                  
                )
            )
          )
          (
            templateSensorTemperature "floor1/badkamer/temperature_auto_wanted" (
              temperatureSets
                (windowClosed
                  "binary_sensor.floor1_badkamer_window_na_contact"
                  (inUse
                    "input_boolean.floor1_badkamer_in_use"
                    (workday
                      ''
                        {% if now().hour >= 6 and now().hour < 7 %}
                          {{ temperature_night }}
                        {% elif now().hour >= 18 and now().hour < 21 %}
                          {{ temperature_night }}
                        {% else %}
                          {{ temperature_eco }}
                        {% endif %}
                      ''
                      ''
                        {% if now().hour >= 9 and now().hour < 21 %}
                          {{ temperature_night }}
                        {% else %}
                          {{ temperature_eco }}
                        {% endif %}
                      ''
                    )
                  )
                )
            )
          )
          (
            templateSensorTemperature "floor0/keuken/temperature_auto_wanted" (temperatureSets "{{ temperature_eco }}")
          )
          (
            templateSensorTemperature "floor0/bureau/temperature_auto_wanted" (
              temperatureSets
                (inUseBeforeNight
                  "input_boolean.floor0_bureau_in_use"
                  (workday
                    ''
                      {{ temperature_eco }}
                    ''
                    ''
                      {% if now().hour >= 9 and now().hour < 18 %}
                        {% if anyone_home %}
                          {{ temperature_comfort_low }}
                        {% else %}
                          {{ temperature_eco }}
                        {% endif %}
                      {% else %}
                        {{ temperature_eco }}
                      {% endif %}
                    ''
                  )
                )
            )
          )
          (
            templateSensorTemperature "floor0/living/temperature_auto_wanted" (
              temperatureSets
                (inUseBeforeNight
                  "input_boolean.floor0_living_in_use"
                  (workday
                    ''
                      {% if now().hour >= 18 and now().hour < 22 %}
                        {{ temperature_comfort }}
                      {% elif now().hour >= 16 and now().hour <= 17 %}
                        {{ temperature_comfort_low }}
                      {% else %}
                        {{ temperature_eco }}
                      {% endif %}
                    ''
                    ''
                      {% if now().hour >= 7 and now().hour < 22 %}
                        {{ temperature_comfort }}
                      {% else %}
                        {{ temperature_eco }}
                      {% endif %}
                    ''
                  )
                )
            )
          )
        ]
        ++ map (v: roomTempFunction { floor = "floor0"; room = v; sensors = ["floor0_${v}_temperature_na_temperature"]; adjustment = -0.3; }) (builtins.filter (v: v != "living") rooms.floor0)
        ++ map (v: roomTempFunction { floor = "floor0"; room = v; sensors = [ "ebusd_370_displayedroomtemp_temp" "floor0_${v}_temperature_na_temperature" "floor0_living_fire_alarm_temperature" ]; }) [ "living" ]
        ++ map (v: roomTempFunction { floor = "floor1"; room = v; sensors = [ "floor1_${v}_temperature_na_temperature" ]; adjustment = -0.3; }) rooms.floor1
        ++ map (v: roomTempFunction { floor = "basement"; room = v; sensors = ["basement_${v}_temperature_na_temperature" ]; }) rooms.basement
        ++ map
          (
            v: templateSensorTemperature "${v}_temperature_diff_wanted" ''
              {% set temperature_wanted = states("sensor.${v}_temperature_auto_wanted") | float(15.5) %}
              {% set temperature_actual = states("sensor.${v}_temperature") | float(15.5) %}
              {{ (temperature_wanted - temperature_actual) | round(2) }}
            ''
          )
          heatedRooms
        ++ map (v: roomHumidityFunction { floor = "floor0"; room = v; sensors = ["floor0_${v}_temperature_na_humidity"]; adjustment = -5; }) (builtins.filter (v: v != "living") rooms.floor0)
        ++ map (v: roomHumidityFunction { floor = "floor0"; room = v; sensors = [ "floor0_${v}_temperature_na_humidity" "floor0_living_fire_alarm_humidity" ]; }) [ "living" ]
        ++ map (v: roomHumidityFunction { floor = "floor1"; room = v; sensors = [ "floor1_${v}_temperature_na_humidity" ]; adjustment = -5; }) rooms.floor1
        ++ map (v: roomHumidityFunction { floor = "basement"; room = v; sensors = ["basement_${v}_temperature_na_humidity"]; adjustment = -5; }) rooms.basement;
      }
    ];

    recorder = {
      include = {
        entities = [
        ]
        ++ map(v: "sensor.${v}_temperature") rooms.all
        ++ map(v: "sensor.${v}_temperature_diff_wanted") rooms.all
        ++ map(v: "sensor.${v}_temperature_auto_wanted") rooms.all
        ++ map(v: "sensor.${v}_humidity") rooms.all;
      };
      exclude = {
        entity_globs = [
          "sensor.*_*_rtv_*_temperature*"
          "sensor.*_*_temperature_na_*"
        ];
      };
    };
  };

}
