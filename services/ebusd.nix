{ channels, config, pkgs, lib, ... }:
{

  services.ebusd = {
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
      other = "notice";
      all = "error";
    };
    extraArguments = [
      "--latency=100" 
      "--acquiretimeout=100" 
      "--acquireretries=3" 
      "--receivetimeout=100"
      "--sendretries=3"
      "--pollinterval=50" ];
  };

}
