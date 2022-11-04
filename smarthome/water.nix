{
  mqtt = {
    binary_sensor = [
      {
        name = "watermeter_leak_detect";
        state_topic = "watermeter/reading/watermeter_leak_detect";
      }
    ];

    sensor = [    
      {
        name = "watermeter_total";
        state_topic = "watermeter/reading/current_value";
        unique_id = "watermeter_total";
        state_class = "total_increasing";
        unit_of_measurement = "L";
        force_update = true;
        icon = "mdi:water";
      }
      {
        name = "watermeter_usage_last_minute";
        state_topic = "watermeter/reading/water_used_last_minute";
        unit_of_measurement = "L";
        icon = "mdi:water";
        unique_id = "watermeter_usage_last_minute";
      }
    ];

  };

  utility_meter = {
    water_delivery = {
      source = "sensor.watermeter_total";
    };    
    water_delivery_hourly = {
      source = "sensor.watermeter_total";
      cycle = "hourly";
    };
    water_delivery_daily = {
      source = "sensor.watermeter_total";
      cycle = "daily";
    };
    water_delivery_weekly = {
      source = "sensor.watermeter_total";
      cycle = "weekly";
    };
    water_delivery_monthly = {
      source = "sensor.watermeter_total";
      cycle = "monthly";
    };
    water_delivery_yearly = {
      source = "sensor.watermeter_total";
      cycle = "yearly";
    };
  };
}