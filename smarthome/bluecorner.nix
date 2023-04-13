{config, pkgs, ...}:

{

  template = [];
  sensor = [
    {
      platform = "command_line";
      command = ''${pkgs.curl}/bin/curl --silent 'https://oauth.bluecorner.be/connect/token' -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data-raw 'request_type=si%3As&refresh_token={{ states('sensor.bluecorner_refresh_token')}}&grant_type=refresh_token&client_id=BCCP' '';
      name = "bluecorner_token";
      scan_interval = 1800;
      json_attributes = ["access_token"];
      value_template = ''{{ value_json.refresh_token }}''; # https://community.home-assistant.io/t/rest-sensor-state-max-length-is-255-characters/31807/10
    }    
    {
      platform = "rest";
      resource = "https://api.bluecorner.be/blue/api//v3.1/session/BCO/sessionlist/filtered?pagesize=1&pagenumber=1&caching=0&filter=%7B%7D&type=0";
      name = "bluecorner_total";
      scan_interval = 900;
      headers = {
        Authorization = ''Bearer {{ state_attr('sensor.bluecorner_token', 'access_token')}} '';
        Accept = "application/json";
      };
      json_attributes_path = ''$.data.records[0]'';
      json_attributes = ["SessionId"];      
      value_template = ''{{ value_json.data.records[0].Consumption | float / 1000 }}'';
      unit_of_measurement = "kWh";
      device_class = "energy";
      icon = "mdi:car-electric";
      state_class = "total_increasing";
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
        {{ is_state('sensor.bluecorner_token', 'unknown') or (states('sensor.bluecorner_token')|length == 0) }}
      '';
      action = [
        {
	        service = "mqtt.publish";
          data = {
            topic = "bluecorner/refresh_token";
            payload_template = ''
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
}
