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
            name = "indoor/dewpoint";
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
            name = "outdoor/dewpoint";
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
          (
            ha.sensor.avg_from_list "outdoor/humidity" [
              "states('sensor.system_wtw_air_quality_inlet_humidity')" 
              "states('sensor.garden_garden_temperature_noordkant_humidity')" 
              "states('sensor.openweathermap_humidity')"
              "states('sensor.irceline_sint_kruiswinkel_humidity')"
            ]
            {
              unit_of_measurement = "%";
              device_class = "humidity";
              icon = "mdi:water-percent";
            }
          )
          (
            ha.sensor.avg_from_list "outdoor/temperature" [
              "states('sensor.garden_garden_temperature_noordkant_temperature')"
              "states('sensor.garden_garden_temperature_noordkant_temperature')"
              "states('sensor.garden_garden_temperature_noordkant_temperature')"
              "states('sensor.openweathermap_temperature')"
              #"states('sensor.system_wtw_air_quality_inlet_temperature')"
              #"states('sensor.itho_wtw_inlet_temperature')"
              "states('sensor.irceline_sint_kruiswinkel_temperature')"
            ]
            {
              unit_of_measurement = "°C";
              icon = "mdi:home-thermometer-outline";
              device_class = "temperature";
            }
          )
          (
            ha.sensor.avg_from_list "indoor/humidity" ([
              "states('sensor.system_wtw_air_quality_outlet_humidity')"
            ]
            ++ map(v: "states('sensor.${v}_humidity')") rooms.heated)
            {
              unit_of_measurement = "%";
              device_class = "humidity";
              icon = ''
                {% if states('sensor.indoor_humidity') | float(100) > 70 %}
                    mdi:water-percent-alert
                {% else %}
                    mdi:water-percent
                {% endif %}
            '';
            }
          )          
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
            device_class = "humidity";
          }
          (
            ha.sensor.avg_from_list "indoor/temperature" ([
              "states('sensor.system_wtw_air_quality_outlet_temperature')"
              "states('sensor.itho_wtw_outlet_temperature')"
            ] 
            ++ map(v: "states('sensor.${v}_temperature')") rooms.heated
            ++ map(v: "states('sensor.${v}_temperature')") rooms.all)
            {
              unit_of_measurement = "°C";
              icon = "mdi:home-thermometer-outline";
              device_class = "temperature";
            }
          )
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
        entity_globs = [
          "sensor.*_temperature"
          "sensor.*_humidity"
        ];
      };
    };

  };

}

