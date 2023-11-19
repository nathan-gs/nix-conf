{config, pkgs, ...}:

let
  aqSensors = import ./devices/air_quality.nix;

in
{

  scrape = [];

  template = [
    {
      sensor = [
        
      ];
    }
  ];

  sensor = [];

  utility_meter = {};
  customize = {};

  automations = [];

  binary_sensor = [];

  zigbeeDevices = { };
  
  

  devices = []
    ++ map (v: v // { 
      type = "air_quality";
      zone = "wtw";
      floor = "system";
    }) aqSensors;

  climate = [];

  recorder_excludes = [ ];
}
