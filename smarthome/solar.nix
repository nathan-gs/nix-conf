let

in
{

  template = [];
  sensor = [
    {
      platform = "rest";
      resource = "http://192.168.1.24/inverter.cgi";
      name = "solar_solis_inverter_cgi";
      scan_interval = 30;
      username = config.secrets.solis.s3wifist.username;
      password = config.secrets.solis.s3wifist.password;
    }    
  ];
  utility_meter = {};
  customize = {};
  automations = [];
}
