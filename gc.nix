{ config, pkgs, lib, ... }:

{


  nix.gc = {
    automatic = true;
    dates = "weekly";
  };  

  boot.loader.grub.configurationLimit = 5;

}
