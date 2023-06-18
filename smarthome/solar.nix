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
          state_class = "measurement";
        }
        {
          name = "solar_delivery_daily";
          state = ''        
            {{ ( states('sensor.solar_solis_inverter_cgi').split(";")[5] | float ) }}
          '';      
          unit_of_measurement = "kWh";
          device_class = "energy";
          icon = "mdi:solar-panel";
          state_class = "total";
        }
        {
          name = "solar_delivery_total";
          # Workaround for Solis occasionally reporting the previous total in the first minutes after midnight          
          state = ''
            {% if (now().hour > 3 or now().hour < 23)  %}
              {{ ( states('sensor.solar_delivery_total_till_yesterday') | float(0) ) + (states('sensor.solar_delivery_daily') | float(0) ) }}
            {% else %}
              {{ states('sensor.solar_delivery_total') | float(0) }}
            {% endif %}
          '';
          unit_of_measurement = "kWh";
          device_class = "energy";
          icon = "mdi:solar-panel";
          state_class = "total";
        }
      ];
    }
    {
      trigger = {
        platform = "time";
        at = "00:00:00";
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
      resource = "http://solis-s3wifi/inverter.cgi";
      name = "solar_solis_inverter_cgi";
      scan_interval = 60;
      username = "admin";
      password = config.secrets.solis.s3wifist.password;
      value_template = ''{{ value | regex_replace ("[^A-Za-z0-9;\.]","") }}'';
    }    
  ];
  utility_meter = {};
  customize = {};
  automations = [];
  binary_sensor = [];

  recorder_excludes = [
    "sensor.solar_solis_inverter_cgi"
  ];

}
