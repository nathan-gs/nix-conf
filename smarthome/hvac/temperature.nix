{config, pkgs, lib, ha, ...}:

let 
  rooms = import ../rooms.nix;
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
            state_class = "measurement";
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
            state_class = "measurement";
          }
          {
            name = "outdoor_humidity";
            state = ''
              {% set v = [
                states('sensor.system_wtw_air_quality_inlet_humidity'),
                states('sensor.garden_garden_temperature_noordkant_humidity'),
                states('sensor.openweathermap_humidity'),
                states('sensor.irceline_sint_kruiswinkel_humidity')
              ]
              %}
              {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
              {{ (valid_v | sum / valid_v | length) | round(2) }}
            '';
            unit_of_measurement = "%";
            icon = "mdi:water-percent";
            state_class = "measurement";
          }
          {
            name = "outdoor_temperature";
            state = ''
              {% set v = [
                states('sensor.garden_garden_temperature_noordkant_temperature'),
                states('sensor.openweathermap_temperature'),
                states('sensor.system_wtw_air_quality_inlet_temperature'),
                states('sensor.itho_wtw_inlet_temperature'),
                states('sensor.irceline_sint_kruiswinkel_temperature)
              ]
              %}
              {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
              {{ (valid_v | sum / valid_v | length) | round(2) }}
            '';
            unit_of_measurement = "°C";
            icon = "mdi:home-thermometer-outline";
            state_class = "measurement";
          }
          {
            name = "indoor_humidity";
            state = ''
              {% set v = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_humidity')") rooms.heated)},
                states('sensor.system_wtw_air_quality_outlet_humidity')
              ]
              %}
              {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
              {{ (valid_v | sum / valid_v | length) | round(2) }}
            '';
            icon = ''
              {% if states('sensor.indoor_humidity') | float(100) > 70 %}
                  mdi:water-percent-alert
              {% else %}
                  mdi:water-percent
              {% endif %}
            '';
            unit_of_measurement = "%";
            state_class = "measurement";
          }
          {
            name = "indoor_humidity_max";
            state = ''
              {% set v = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_humidity')") rooms.heated)}
              ]
              %}
              {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
              {{ max(valid_v) | round(2) }}
            '';
            icon = ''
              {% if states('sensor.indoor_humidity') | float(100) > 70 %}
                  mdi:water-percent-alert
              {% else %}
                  mdi:water-percent
              {% endif %}
            '';
            unit_of_measurement = "%";
            state_class = "measurement";
          }
          {
            name = "indoor_temperature";
            state = ''
              {% set sensors = [
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature')") rooms.heated)},
                ${builtins.concatStringsSep "," (map(v: "states('sensor.${v}_temperature')") rooms.all)},
                states('sensor.system_wtw_air_quality_outlet_temperature'),
                states('sensor.itho_wtw_outlet_temperature')
              ] %}
              {% set valid_v = sensors | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
              {{ (valid_v | sum / valid_v | length) | round(2) }}
            '';
            icon = "mdi:home-thermometer";
            unit_of_measurement = "°C";
            state_class = "measurement";
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

    recorder = {
      include = {
        entities = [
          "sensor.indoor_dewpoint"
          "sensor.outdoor_dewpoint"
          "sensor.outdoor_humidity"
          "sensor.outdoor_temperature"
          "sensor.outdoor_temperature_24h_avg"
          "sensor.indoor_humidity"
          "sensor.indoor_humidity_max"
          "sensor.indoor_temperature"
        ];
      };
    };

  };

}

