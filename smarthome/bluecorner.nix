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
        "Authorization" = "Bearer {{ state_attr('sensor.bluecorner_token', 'refresh_token')}}"
      };
      json_attributes = ["refresh_token", "access_token"];
    }    
  ];
  utility_meter = {};
  customize = {};
  automations = [];
  binary_sensor = [];
}
