{ config, pkgs, ... }:

{

  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;
    "vm.dirty_writeback_centisecs" = 6000;
    "vm.swappiness" = 0;
  };

  hardware.bluetooth.powerOnBoot = false;

  boot.blacklistedKernelModules = [ "bluetooth" ];

#  powerManagement.scsiLinkPolicy = "min_power";

  powerManagement.cpuFreqGovernor = "powersave";  
#  services.thermald.enable = true;


}
