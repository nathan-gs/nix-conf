{config, pkgs, lib, ...}:

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
              {{ (temp - ((100 - (rh * 100)) / 5)) | round(2) }}
            '';
            unit_of_measurement = "°C";
            icon = "mdi:water-percent";
          }
          {
            name = "outdoor_dewpoint";
            state = ''
              {% set rh = states('sensor.outdoor_humidity') | float(60) / 100 %}
              {% set temp = states('sensor.outdoor_temperature') | float(16) %}
              {{ (temp - ((100 - (rh * 100)) / 5)) | round(2) }}
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
            name = "outdoor_temperature_raw";
            state = ''
              {% set itho_wtw = states('sensor.itho_wtw_inlet_temperature') | float(16) %}
              {% set inlet = states('sensor.system_wtw_air_quality_inlet_temperature') | float(16) %}
              {% set garden = states('sensor.garden_garden_temperature_noordkant_temperature') | float(16) %}
              {% set openweather = states('sensor.openweathermap_temperature') | float(itho_wtw) %}
              {% set sum = itho_wtw + inlet + garden + openweather %}
              {{ (sum / 4) | round(2) }}
            '';
            unit_of_measurement = "°C";
            icon = "mdi:home-thermometer-outline";
          }
          {
            name = "indoor_humidity";
            state = ''
              {% set v = (
                states("sensor.floor0_bureau_temperature_na_humidity"),
                states("sensor.floor0_keuken_temperature_na_humidity"),
                states("sensor.floor0_living_temperature_na_humidity"),
                states("sensor.floor1_badkamer_temperature_na_humidity"),
                states("sensor.floor1_fen_temperature_na_humidity"),
                states("sensor.floor1_morgane_temperature_na_humidity"),
                states("sensor.floor1_nikolai_temperature_na_humidity")
              )  
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
              {% set v = (
                states("sensor.floor0_bureau_temperature_na_humidity"),
                states("sensor.floor0_keuken_temperature_na_humidity"),
                states("sensor.floor0_living_temperature_na_humidity"),
                states("sensor.floor1_badkamer_temperature_na_humidity"),
                states("sensor.floor1_fen_temperature_na_humidity"),
                states("sensor.floor1_morgane_temperature_na_humidity"),
                states("sensor.floor1_nikolai_temperature_na_humidity")
              )  
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
                states('sensor.floor0_bureau_temperature_na_temperature'),
                states('sensor.floor0_keuken_temperature_na_temperature'),
                states('sensor.floor0_living_temperature_na_temperature'),
                states('sensor.floor1_badkamer_temperature_na_temperature'),
                states('sensor.floor1_fen_temperature_na_temperature'),
                states('sensor.floor1_morgane_temperature_na_temperature'),
                states('sensor.floor1_nikolai_temperature_na_temperature'),
                states('sensor.ebusd_370_displayedroomtemp_temp')
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
        name = "outdoor_temperature";
        entity_id = "sensor.outdoor_temperature_raw";
        state_characteristic = "mean";
        max_age.minutes = 6;
        sampling_size = 10;
      }
      {
        platform = "statistics";
        name = "outside_temperature_24h_avg";
        entity_id = "sensor.outdoor_temperature_raw";
        state_characteristic = "mean";
        max_age.hours = 24;
        sampling_size = 60*24;
      }
    ];
  };


}

