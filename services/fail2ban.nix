{ config, pkgs, lib, ... }:
{
  services.fail2ban = {
    enable = true;
    bantime-increment.enable = true;
  };

}
