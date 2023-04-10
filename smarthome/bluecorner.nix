{config, ...}:

{

  template = [  

  ];
  sensor = [
    {
      platform = "rest";
      resource = "https://oauth.bluecorner.be/connect/token";
      name = "bluecorner_token";
      method = "POST";
      scan_interval = 900;
      headers = {
        Accept = "application/json";
        "Content-Type" = "application/x-www-form-urlencoded";
      };
      payload = ''
        request_type=si%3As&refresh_token={{ state_attr('sensor.bluecorner_token', 'refresh_token')}}&grant_type=refresh_token&client_id=BCCP
      '';
      json_attributes = ["refresh_token" "access_token"];
    }    
  ];
  utility_meter = {};
  customize = {};
  automations = [];
  binary_sensor = [];
}
