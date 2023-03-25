{config, ...}:

{

  template = [  
    {
      sensor = [
        {
          name = "solar_currently_produced";
          state = ''        
            {{ (( states('sensor.solar_solis_inverter_cgi').split(";")[4] | float ) / 1000 ) | float }}
          '';      
          unit_of_measurement = "kW";
          device_class = "power";
          icon = "mdi:solar-panel";
        }
        {
          name = "solar_delivery_daily";
          state = ''        
            {{ ( states('sensor.solar_solis_inverter_cgi').split(";")[5] | float ) }}
          '';      
          unit_of_measurement = "kWh";
          device_class = "energy";
          icon = "mdi:solar-panel";
        }
        {
          name = "solar_delivery_total";
          state = ''
            {{ ( states('sensor.solar_delivery_total_till_yesterday') | float(0) ) + (states('sensor.solar_delivery_daily') | float(0) ) }}
          '';
          unit_of_measurement = "kWh";
          device_class = "energy";
          icon = "mdi:solar-panel";
        }
      ];
    }
    {
      trigger = {
        platform = "time";
        minutes = "23:59:00";
      };
      sensor = [
        {
          name = "solar_delivery_total_till_yesterday";
          state = ''        
            {{ states('sensor.solar_delivery_total')| float(0) }}
          '';      
          unit_of_measurement = "kWh";
          device_class = "energy";
          icon = "mdi:solar-panel";
        }
      ];
    }
  ];
  sensor = [
    {
      platform = "rest";
      resource = "http://192.168.1.24/inverter.cgi";
      name = "solar_solis_inverter_cgi";
      scan_interval = 30;
      username = "admin";
      password = config.secrets.solis.s3wifist.password;
      value_template = ''{{ value | regex_replace ("[^A-Za-z0-9]","") }}'';
    }    
  ];
  utility_meter = {};
  customize = {};
  automations = [];
  binary_sensor = [];
}
