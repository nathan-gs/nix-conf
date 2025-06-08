{ config, pkgs, lib, ha, ... }:

let
  rooms = import ../rooms.nix;
  temperatureHeader = import ./temperature_sets.nix;

  heatedRooms = rooms.heated;

  temperatureSets = content: ''
    ${temperatureHeader}
    ${content}
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

  roomTempFunction = { floor, room, sensors, adjustments }: 
    ha.sensor.avg_from_list "${floor}/${room}/temperature" (map(v: "states('sensor.${v}')") sensors) {
      unit_of_measurement = "°C";
      device_class = "temperature";
      adjustments = adjustments;
      icon = "mdi:thermometer";
    };

  roomHumidityFunction = { floor, room, sensors, adjustments }: 
    ha.sensor.avg_from_list "${floor}/${room}/humidity" (map(v: "states('sensor.${v}')") sensors) {
      unit_of_measurement = "%";
      device_class = "humidity";
      adjustments = adjustments;
      icon = ''
          {% if states('sensor.${floor}_${room}_humidity') | float(100) > 70 %}
              mdi:water-percent-alert
          {% else %}
              mdi:water-percent
          {% endif %}
      '';
    };

in
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [
          (
            templateSensorTemperature "floor1/nikolai/temperature_auto_wanted" (
              (temperatureSets                
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
              (temperatureSets                
                (workday
                  (kidsRoomWorkdayTemperature)
                  (kidsRoomWeekendTemperature)
                )
              )
            )
          )
          (
            templateSensorTemperature "floor1/fen/temperature_auto_wanted" (
              (temperatureSets                
                (kidsRoomWorkdayTemperature)
              )
            )
          )
          (
            templateSensorTemperature "floor1/badkamer/temperature_auto_wanted" (
              (temperatureSets                
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
            templateSensorTemperature "floor0/keuken/temperature_auto_wanted" (temperatureSets "{{ temperature_away }}")
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
        ++ [(roomTempFunction { floor = "floor1"; room = "fen"; sensors = [ "floor1_fen_temperature_na_temperature" "floor1_fen_switchbot" ]; adjustments = ["-0.3" "0" ];})]
        ++ map (v: roomTempFunction { floor = "floor0"; room = v; sensors = ["floor0_${v}_temperature_na_temperature"]; adjustments = ["-0.3"]; }) (builtins.filter (room: room != "living" && room != "bureau") rooms.floor0)
        ++ map (v: roomTempFunction { floor = "floor0"; room = v; sensors = [ "floor0_${v}_temperature_na_temperature" "floor0_bureau_switchbot" ]; adjustments = ["-0.3" "0"];}) [ "bureau" ]
        ++ map (v: roomTempFunction { floor = "floor0"; room = v; sensors = [ "ebusd_370_displayedroomtemp_temp" "floor0_${v}_temperature_na_temperature" "floor0_living_fire_alarm_main_temperature" "floor0_living_switchbot" ]; adjustments = ["0" "-0.3" "0" "0"];}) [ "living" ]
        ++ map (v: roomTempFunction { floor = "floor1"; room = v; sensors = [ "floor1_${v}_temperature_na_temperature" ]; adjustments = ["-0.3"]; }) (builtins.filter (v: v != "fen") rooms.floor1)
        ++ map (v: roomTempFunction { floor = "basement"; room = v; sensors = ["basement_${v}_temperature_na_temperature" ]; adjustments = ["-0.3"]; }) rooms.basement
        ++ map
          (
            v: templateSensorTemperature "${v}_temperature_diff_wanted" ''
              {% set temperature_wanted = states("sensor.${v}_temperature_auto_wanted") | float(15.5) %}
              {% set temperature_actual = states("sensor.${v}_temperature") | float(15.5) %}
              {{ (temperature_wanted - temperature_actual) | round(2) }}
            ''
          )
          heatedRooms
        ++ map (v: roomHumidityFunction { floor = "floor0"; room = v; sensors = ["floor0_${v}_temperature_na_humidity"]; adjustments = [ "-5" ]; })  (builtins.filter (room: room != "living" && room != "bureau") rooms.floor0)
        ++ map (v: roomHumidityFunction { floor = "floor0"; room = v; sensors = [ "floor0_${v}_temperature_na_humidity" "floor0_living_fire_alarm_main_humidity" "floor0_living_fire_alarm_main_humidity" "floor0_living_switchbot_humidity" ]; adjustments = [ "-5" "0" "0"]; }) [ "living" ]
        ++ map (v: roomHumidityFunction { floor = "floor1"; room = v; sensors = [ "floor1_${v}_temperature_na_humidity" ]; adjustments = ["-5"]; }) (builtins.filter (v: v != "fen") rooms.floor1)
        ++ [(roomHumidityFunction { floor = "floor1"; room = "fen"; sensors = [ "floor1_fen_temperature_na_humidity" "floor1_fen_switchbot_humidity" ]; adjustments = ["-5" "0"];})]
        ++ map (v: roomHumidityFunction { floor = "floor0"; room = v; sensors = [ "floor0_${v}_temperature_na_humidity" "floor0_bureau_switchbot_humidity" ]; adjustments = ["-5" "0"];}) [ "bureau" ]
        ++ map (v: roomHumidityFunction { floor = "basement"; room = v; sensors = ["basement_${v}_temperature_na_humidity"]; adjustments = ["-5"]; }) rooms.basement;
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
