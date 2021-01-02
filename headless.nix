{ config, pkgs, ... }:

{

  sound.enable = false;

  boot.blacklistedKernelModules = [ "snd" ];

  # Enable CUPS to print documents.
  services.printing.enable = false;



}
