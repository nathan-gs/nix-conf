{config, pkgs, ...}:

{

  template = [
    {
      trigger = {
        platform = "state";
        entity_id = "sensor.bluecorner_current_month";
      };
      sensor = [
        {
          name = "bluecorner_total";
          unit_of_measurement = "kWh";
          device_class = "energy";
          icon = "mdi:car-electric";
          state_class = "total";
          state = ''
            {{ states('sensor.bluecorner_total_till_last_month')|float(0) + ( states('sensor.bluecorner_current_month') | float(0) ) }}
          '';
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
          name = "bluecorner_total_till_last_month";
          state = ''
            {% if now().day == 1  %}
              {{ states('sensor.bluecorner_total')| float(0) }}
            {% else %}
              {{ states('bluecorner_total_till_last_month') | float(0) }}
            {% endif %}            
          '';
          unit_of_measurement = "kWh";
          device_class = "energy";
          state_class = "total";
          icon = "mdi:car-electric";
        }
      ];
    }
  ];
  sensor = [
    {
      platform = "command_line";
      command = ''${pkgs.curl}/bin/curl --silent 'https://oauth.bluecorner.be/connect/token' -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data-raw 'request_type=si%3As&refresh_token={{ states('sensor.bluecorner_refresh_token')}}&grant_type=refresh_token&client_id=BCCP' '';
      name = "bluecorner_token";
      scan_interval = 1800;
      json_attributes = ["access_token"];
      # https://community.home-assistant.io/t/rest-sensor-state-max-length-is-255-characters/31807/10
      value_template = ''
        {% if value_json.refresh_token is defined %}
          {{ value_json.refresh_token }}
        {% else %}
          {{ states('sensor.bluecorner_refresh_token') }}
        {% endif %}
      ''; 
    }    
    {
      platform = "rest";
      resource = "https://api.bluecorner.be/blue/api/v3.1/indicator/BCO/KWHMyChargers";
      name = "bluecorner_current_month";
      scan_interval = 900;
      headers = {
        Authorization = ''Bearer {{ state_attr('sensor.bluecorner_token', 'access_token')}} '';
        Accept = "application/json";
      };      
      value_template = ''{{ value_json.data[-1].value | float / 1000 }}'';
      unit_of_measurement = "kWh";
      device_class = "energy";
      state_class = "total";
      icon = "mdi:car-electric";
    }
  ];

  mqtt_sensor =  [
    {
      name = "bluecorner_refresh_token";
      state_topic = "bluecorner/refresh_token";
      unique_id = "bluecorner_refresh_token";
    }
  ];

  utility_meter = {};
  customize = {};

  automations = [
    {
      id = "bluecorner_token.save";
      alias = "bluecorner_token.save";      
      trigger = [        
        {
          platform = "state";
          entity_id = "sensor.bluecorner_token";
        }
      ];
      condition = ''
        {{ not is_state('sensor.bluecorner_token', 'unknown') and (states('sensor.bluecorner_token')|length > 0) }}
      '';
      action = [
        {
	        service = "mqtt.publish";
          data = {
            topic = "bluecorner/refresh_token";
            payload = ''
              {{ states('sensor.bluecorner_token') }}
            '';
            retain = true;
          };
        }        
      ];
      mode = "single";
    }
  ];
  binary_sensor = [];

  recorder_excludes = [
    "sensor.bluecorner_token"
    "sensor.bluecorner_refresh_token"
  ];
}
