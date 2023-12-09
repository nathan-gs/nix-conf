{config, pkgs, lib, ha, ...}:

let 
  rooms = import ../rooms.nix;

  roomTempFunction = {floor, room, sensor1, sensor2 ? null} : {
    name = "${floor}_${room}_temperature";
    state = ''
      {% set sensor2 = ${if !isNull sensor2 then "states('sensor.${sensor2}')" else "0"} | float(0) %}      
      {% set sensor1 = states('sensor.${sensor1}') | float(sensor2) %}
      {{ sensor1 }}
    '';
    unit_of_measurement = "°C";
    device_class = "temperature";
  };
in 
{

  services.home-assistant.config = {

    template = [
      {
        sensor = [        
          {
            name = "indoor_dewpoint";
            state = ''
              {% set rh = states('sensor.indoor_humidity') | float(60) / 100 %}
              {% set temp = states('sensor.indoor_temperature') | float(20) %}
              {% set a = 17.27 %}
              {% set b = 237.7 %}
              {% set alpha = ((a * temp) / (b + temp)) + ((rh | log) * 2.30259) %}
              {{ ((b * alpha) / (a - alpha)) | round(2) }}
            '';
            unit_of_measurement = "°C";
            icon = "mdi:water-percent";
          }
          {
            name = "outdoor_dewpoint";
            state = ''
              {% set rh = states('sensor.outdoor_humidity') | float(60) / 100 %}
              {% set temp = states('sensor.outdoor_temperature') | float(16) %}
              {% set a = 17.27 %}
              {% set b = 237.7 %}
              {% set alpha = ((a * temp) / (b + temp)) + ((rh | log) * 2.30259) %}
              {{ ((b * alpha) / (a - alpha)) | round(2) }}
            '';
            unit_of_measurement = "°C";
            icon = "mdi:water-percent";
          }
          {
            name = "outdoor_humidity";
            state = ''
              {% set rh1 = states('sensor.system_wtw_air_quality_inlet_humidity') | float(60) %}
              {% set rh2 = states('sensor.openweathermap_humidity') | float(60) %}
              {% set rh = (rh1 + rh2) / 2 %}
              {{ rh | round(2) }}
            '';
            unit_of_measurement = "%";
            icon = "mdi:water-percent";
          }
          {
            name = "outdoor_temperature";
            state = ''
              {#
              {% set itho_wtw = states('sensor.itho_wtw_inlet_temperature') | float(16) %}
              {% set inlet = states('sensor.system_wtw_air_quality_inlet_temperature') | float(16) %}
              #}
              {% set garden = states('sensor.garden_garden_temperature_noordkant_temperature') | float(16) %}
              {% set openweather = states('sensor.openweathermap_temperature') | float(garden) %}
              {% set sum = garden + openweather %}
              {{ (sum / 2) | round(2) }}
            '';
            unit_of_measurement = "°C";
            icon = "mdi:home-thermometer-outline";
          }
          {
            name = "indoor_humidity";
            state = ''
              {% set v = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature_na_humidity')") rooms.all)}
              ]
              %}
              {% set valid_humidities = v | select('!=','unknown') | map('float') | list %}
              {{ (valid_humidities | sum / valid_humidities | length) | round(2) }}
            '';
            icon = ''
              {% if states('sensor.indoor_humidity') | float(100) > 70 %}
                  mdi:water-percent-alert
              {% else %}
                  mdi:water-percent
              {% endif %}
            '';
            unit_of_measurement = "%";
          }
          {
            name = "indoor_humidity_max";
            state = ''
              {% set v = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature_na_humidity')") rooms.all)}
              ]
              %}
              {% set valid_humidities = v | select('!=','unknown') | map('float') | list %}
              {{ max(valid_humidities) | round(2) }}
            '';
            icon = ''
              {% if states('sensor.indoor_humidity') | float(100) > 70 %}
                  mdi:water-percent-alert
              {% else %}
                  mdi:water-percent
              {% endif %}
            '';
            unit_of_measurement = "%";
          }
          {
            name = "indoor_temperature";
            state = ''
              {% set sensors = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature')") rooms.all)}
              ] %}
              {% set valid_temperatures = sensors | select('!=','unknown') | map('float') | list %}
              {{ (valid_temperatures | sum / valid_temperatures | length) | round(2) }}
            '';
            icon = "mdi:home-thermometer";
            unit_of_measurement = "°C";
          }
        ];
      }
    ];

    sensor = [
      {
        platform = "statistics";
        name = "outdoor_temperature_24h_avg";
        entity_id = "sensor.outdoor_temperature";
        state_characteristic = "mean";
        max_age.hours = 24;
        sampling_size = 60*24;
      }
    ];

  };

}

