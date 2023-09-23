{config, pkgs, ...}:

let
  aqSensors = [
    {      
      name = "inlet";
      ieee = "0xbc026efffea63649";
    }
    {      
      name = "to_house";
      ieee = "0x3425b4fffe974ccd";
    }
    {
      name = "outlet";
      ieee = "0x3425b4fffe970e3d";
    }
  ];

in
{

  scrape = [];

  template = [
    {
      sensor = [
        {
          name = "wtw_target_fan";
          state = ''
            {% set is_home = states('binary_sensor.is_anyone_home') %}
            {% set is_cooking = false %}
            {% set is_using_sanitary = false %}
            {% set is_very_moist = (states('sensor.indoor_humidity_max') | float > 70) %}
            {% set is_using_dryer = (states('sensor.floor1_waskot_metering_plug_droogkast_power') | float > 100)  %}
            {% set indoor_temperature = states('sensor.indoor_temperature_mean') | float %}
            {% set outdoor_temperature = states('sensor.garden_garden_temperature_noordkant_temperature') | float %}
            {% set house_needs_cooling = indoor_temperature > 24 %}
            {% set house_needs_cooling_and_temp_outside_lower = false %}
            {% if house_needs_cooling and outdoor_temperature < indoor_temperature %}
              {% set house_needs_cooling_and_temp_outside_lower = true %}
            {% endif %}

            {% if is_cooking or is_using_sanitary or is_very_moist or is_using_dryer or house_needs_cooling_and_temp_outside_lower %}
              high
            {% elif is_home %}
              medium
            {% else %}
              low
            {% endif %}
          '';
        }
      ];
    }
  ];

  sensor = [
    {
      name = "indoor_humidity_max";
      platform = "min_max";
      type = "max";
      entity_ids = [
        # sensor.basement_basement_temperature_na_humidity
        "sensor.floor0_bureau_temperature_na_humidity"
        "sensor.floor0_keuken_temperature_na_humidity"
        "sensor.floor0_living_temperature_na_humidity"
        "sensor.floor1_badkamer_temperature_na_humidity"
        "sensor.floor1_fen_temperature_na_humidity"
        "sensor.floor1_morgane_temperature_na_humidity"
        "sensor.floor1_nikolai_temperature_na_humidity"
      ];
    }
    {
      name = "indoor_temperature_mean";
      platform = "min_max";
      type = "mean";
      entity_ids = [
        # sensor.basement_basement_temperature_na_temperature
        "sensor.floor0_bureau_temperature_na_temperature"
        "sensor.floor0_keuken_temperature_na_temperature"
        "sensor.floor0_living_temperature_na_temperature"
        "sensor.floor1_badkamer_temperature_na_temperature"
        "sensor.floor1_fen_temperature_na_temperature"
        "sensor.floor1_morgane_temperature_na_temperature"
        "sensor.floor1_nikolai_temperature_na_temperature"
      ];
    }
  ];

  utility_meter = {};
  customize = {};

  automations = [   
  ];
  binary_sensor = [];

  zigbeeDevices = { };
  
  mqtt.climate = [
    
  ];

  devices = []
    ++ map (v: v // { 
      type = "air_quality";
      zone = "wtw";
      floor = "system";
    }) aqSensors;

  climate = [];

  recorder_excludes = [ ];
}
