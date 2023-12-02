{ config, pkgs, lib, ... }:
{
  services.fail2ban = {
    enable = true;
    bantime-increment.enable = true;
    ignoreIP = [
      "192.168.1.0/24"
    ];
  };

}
