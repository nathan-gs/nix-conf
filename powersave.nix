{ config, pkgs, lib, ... }:

{

  powerManagement = {
    enable = true;
    powertop.enable = true;
    scsiLinkPolicy = "med_power_with_dipm";
    cpuFreqGovernor = "powersave";
  };

  boot.kernel.sysctl = {
    "vm.dirty_writeback_centisecs" = 6000;
    "vm.swappiness" = 0;
  };

  # https://www.reddit.com/r/linux/comments/lhgx9/how_can_i_reduce_my_power_consumption/
  boot.kernelParams = [
    "pcie_aspm=force"
    "i915.i915_enable_rc6=1"
    "i915.i915_enable_fbc=1"
    "i915.lvds_downclock=1"
  ];

  systemd.services.powersave = {
    description = "Power Save scripts";
    wantedBy = [ "multi-user.target" ];
    script =
      ''
      set_and_echo() {
        file="$1"
        value="$2"

        original="$(cat $file)"
        if [ "$original" != "$value" ]; then 
          echo "$value" > $file || true
          current="$(cat $file)"
          echo "Changed $file from $original to $current"
        fi
      }

      # https://wiki.archlinux.org/title/Power_management
      for i in $(find /sys/devices/system/cpu/cpufreq/policy? -name energy_performance_preference -writable);
      do
        set_and_echo $i balance_power          
      done

      # https://www.kernel.org/doc/html/latest/admin-guide/pm/intel_epb.html
      for i in $(find /sys/devices/system/cpu/cpu*/power/ -name energy_perf_bias -writable);
      do
        set_and_echo $i balance-power        
      done

      # https://www.kernel.org/doc/html/latest/admin-guide/pm/intel_pstate.html
      set_and_echo /sys/devices/system/cpu/intel_pstate/energy_efficiency 1
      set_and_echo /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost 1
  
      '';
    serviceConfig.Type = "oneshot";
  };

  services.udev = {
    extraRules = 
      ''
      SUBSYSTEM=="pci", ATTR{power/control}="auto"
      SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"
      '';
  };   

  hardware.bluetooth.powerOnBoot = false;
  hardware.bluetooth.enable = false;

  boot.blacklistedKernelModules = [ "bluetooth" "iwlwifi" ];
#  services.thermald.enable = true;


}
