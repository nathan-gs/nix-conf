{ config, pkgs, lib, ... }:

{


  nix.gc = {
    automatic = true;
    dates = "weekly";
  };  

  boot.loader.systemd-boot.configurationLimit = 5;

}
