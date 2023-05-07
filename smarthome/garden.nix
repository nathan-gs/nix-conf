{config, pkgs, ...}:

{

  template = [
    
  ];
  sensor = [
    {
      platform = "statistics";
      name = "rainfall_5d";
      entity_id = "sensor.openweathermap_forecast_precipitation";
      state_characteristic = "total";
      max_age.hours = 24 * 5;
      sampling_size = 60 * 24 * 5;
      unit_of_measurement = "mm";
    }
  ];

  mqtt_sensor =  [];

  utility_meter = {};
  customize = {};

  automations = [   
  ];
  binary_sensor = [];

  recorder_excludes = [ ];
}
