{ config, pkgs, lib, ... }:

{

  systemd.services.powersave = {
    description = "Power Save scripts";
    wantedBy = [ "multi-user.target" ];

    script = ''

#for i in `ls /sys/class/net/ | grep -v lo`;
#do
#  ${pkgs.ethtool}/bin/ethtool -s $i wol d;
#done
echo '6000' > /proc/sys/vm/dirty_writeback_centisecs
echo '0' > /proc/sys/vm/swappiness

for i in $(find /sys/class/scsi_host/*/ -name link_power_management_policy -writable);
do
  original="$(cat $i)" 
  echo 'min_power' > $i || true
  current="$(cat $i)"
  echo "Changing $i from $original to $current"
done

for i in $(find /sys/bus/*/devices/*/power -name control -writable);
do 
  original="$(cat $i)" 
  echo 'auto' > $i || true
  current="$(cat $i)"
  echo "Changing $i from $original to $current"
done

for i in $(find /sys/module/*/ -name power_save -writable);
do 
  original="$(cat $i)" 
  echo '1' > $i || true
  current="$(cat $i)"
  echo "Changing $i from $original to $current"

done

#echo '1' > /sys/module/snd_hda_intel/parameters/power_save
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

  boot.blacklistedKernelModules = [ "bluetooth" ];

#  powerManagement.scsiLinkPolicy = "min_power";

  powerManagement.cpuFreqGovernor = "powersave";  
#  services.thermald.enable = true;


}
