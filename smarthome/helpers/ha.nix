{



  sensorTemperature = name: value: {
    name = name;
    state = value;
    unit_of_measurement = "°C";
    device_class = "temperature";
    icon = "mdi:thermometer-auto";
  };

  automation = name: {triggers ? [], condition = "true", actions = [], mode = "single" } : {
    id = builtins.replaceStrings [ "/" "." ] [ "_" "_" ] name;
    alias = name;
    trigger = triggers;
    condition = condition;
    action = actions;
    mode = mode;
  };

}