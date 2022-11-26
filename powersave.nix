{ config, pkgs, lib, ... }:

{

  powerManagement = {
    enable = true;
    powertop.enable = true;
    scsiLinkPolicy = "med_power_with_dipm";
    cpuFreqGovernor = "powersave";
    powerUpCommands = ''
    # https://wiki.archlinux.org/title/Power_management
    for i in $(find /sys/devices/system/cpu/cpufreq/policy? -name energy_performance_preference -writable);
    do
      original="$(cat $i)" 
      echo 'power' > $i || true
      current="$(cat $i)"
      echo "Changing $i from $original to $current"
    done    
    '';
  };

  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;
    "vm.dirty_writeback_centisecs" = 6000;
    "vm.swappiness" = 0;
  };

#  services.udev = {
#    extraRules = ''
#ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
#ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
#ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="min_power"
#DRIVER=="sd", SUBSYSTEM=="scsi", ENV{DEVTYPE}=="scsi_device", ATTR{timeout}="150"
#    '';
#  };   

  hardware.bluetooth.powerOnBoot = false;

  boot.blacklistedKernelModules = [ "bluetooth" "iwlwifi" ];
#  services.thermald.enable = true;


}
