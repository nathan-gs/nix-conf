{config, pkgs, ...}:

{

  template = [  
    {
      sensor = [
        {
          name = "bluecorner_total";
          unit_of_measurement = "kWh";
          device_class = "energy";
          icon = "mdi:car-electric";
          state_class = "total";
          value_template = ''
            {{ states('sensor.bluecorner_total')|float(0) + states('sensor.bluecorner_last_charging_session')|float }}
          '';
        }
      ];
    }
  ];
  sensor = [
    {
      platform = "command_line";
      command = ''${pkgs.curl}/bin/curl --silent 'https://oauth.bluecorner.be/connect/token' -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data-raw 'request_type=si%3As&refresh_token={{ states('sensor.bluecorner_token')}}&grant_type=refresh_token&client_id=BCCP' '';
      name = "bluecorner_token";
      scan_interval = 900;
      json_attributes = ["access_token"];
      value_template = ''{{ value_json.refresh_token }}''; # https://community.home-assistant.io/t/rest-sensor-state-max-length-is-255-characters/31807/10
    }    
    {
      platform = "rest";
      resource = "https://api.bluecorner.be/blue/api//v3.1/session/BCO/sessionlist/filtered?pagesize=1&pagenumber=1&caching=0&filter=%7B%7D&type=0";
      name = "bluecorner_last_charging_session";
      scan_interval = 3600;
      headers = {
        Authorization = ''Bearer {{ state_attr('sensor.bluecorner_token', 'access_token')}} '';
        Accept = "application/json";
      };
      json_attributes_path = ''$.data.records[0]'';
      json_attributes = ["SessionId"];      
      value_template = ''{{ value_json.data.records[0].Consumption | float | float}}'';
    }  
  ];
  utility_meter = {};
  customize = {};
  automations = [];
  binary_sensor = [];
}
