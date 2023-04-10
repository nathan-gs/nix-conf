{config, ...}:

{

  template = [  

  ];
  sensor = [
    {
      platform = "command_line";
      command = ''python3 -c "import httpx; print(httpx.post('https://oauth.bluecorner.be/connect/token', data={'request_type':si:s', 'refresh_token':'{{ state_attr('sensor.bluecorner_token', 'refresh_token')}}', 'grant_type': 'refresh_token', 'client_id':'BCCP'}).json())"'';      
      name = "bluecorner_token";
      scan_interval = 900;
      json_attributes = ["refresh_token" "access_token"];
    }    
  ];
  utility_meter = {};
  customize = {};
  automations = [];
  binary_sensor = [];
}
