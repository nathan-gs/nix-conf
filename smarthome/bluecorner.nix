{config, pkgs, ...}:

{

  template = [  

  ];
  sensor = [
    {
      platform = "command_line";
      command = ''${pkgs.curl}/bin/curl --silent 'https://oauth.bluecorner.be/connect/token' -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data-raw 'request_type=si%3As&refresh_token={{ state_attr('sensor.bluecorner_token', 'refresh_token')}}&grant_type=refresh_token&client_id=BCCP' '';
      name = "bluecorner_token";
      scan_interval = 900;
      json_attributes = ["refresh_token" "access_token"];
      value_template = 1; # https://community.home-assistant.io/t/rest-sensor-state-max-length-is-255-characters/31807/10
    }    
  ];
  utility_meter = {};
  customize = {};
  automations = [];
  binary_sensor = [];
}
