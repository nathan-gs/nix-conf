{ config, pkgs, ... }:

{

  systemd.services.powersave = {
    description = "Power Save scripts";
    wantedBy = [ "multi-user.target" ];

    script = ''

for i in `ls /sys/class/net/ | grep -v lo`;
do
  ${pkgs.ethtool}/bin/ethtool -s $i wol d;
done

echo '1500' > '/proc/sys/vm/dirty_writeback_centisecs'
for i in `find /sys/class/scsi_host/*/ -name link_power_management_policy`; 
do 
  echo 'min_power' > $i;
done

for i in `find /sys/bus/*/devices/*/power -name control`;
do 
  echo 'auto' > $i;
done

for i in `find /sys/module/ -name power_save`; 
do 
  echo '1' > $i;
  echo "$i >> `cat $i`";
done

echo '1' > /sys/module/snd_hda_intel/parameters/power_save
    '';
  };

  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;
    "vm.dirty_writeback_centisecs" = 6000;
    "vm.swappiness" = 0;
  };

  services.udev = {
    extraRules = ''
ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_policy}="min_power"
DRIVER=="sd", SUBSYSTEM=="scsi", ENV{DEVTYPE}=="scsi_device", ATTR{timeout}="150"
    '';
  };   

  hardware.bluetooth.powerOnBoot = false;

  boot.blacklistedKernelModules = [ "bluetooth" ];

  powerManagement.scsiLinkPolicy = "min_power";

  powerManagement.cpuFreqGovernor = "powersave";  
#  services.thermald.enable = true;


}
