{ channels, config, pkgs, lib, ... }:
{

  imports = [
     ./ebusd-service.nix
  ];

  services.ebusd-t = {
    enable = true;
    device = "enh:ebus:3335";
    mqtt = {
      enable = true;
      host = "localhost";
      user = "ebus";
      password = config.secrets.mqtt.users.ebus.password;
      home-assistant = true;
      retain = true;
    };
    logs = {
      main = "info";
      network = "notice";
      bus = "error";
      update = "error";
      other = "info";
      all = "info";
    };
    extraArguments = [
      "--latency=100" 
      "--acquiretimeout=100" 
      "--acquireretries=3" 
      "--receivetimeout=100"
      "--sendretries=3"
      "--pollinterval=50" ];
  };

  environment.systemPackages = with pkgs; [ 
    ebusd
  ];

}
