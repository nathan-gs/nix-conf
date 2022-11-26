{ config, pkgs, lib, ... }:

{

  powerManagement = {
    enable = true;
    powertop.enable = true;
    scsiLinkPolicy = "med_power_with_dipm";
    cpuFreqGovernor = "powersave";
  };

  boot.kernel.sysctl = {
    "kernel.nmi_watchdog" = 0;
    "vm.dirty_writeback_centisecs" = 6000;
    "vm.swappiness" = 0;
  };

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
          set_and_echo $i power          
        done

        # https://www.kernel.org/doc/html/latest/admin-guide/pm/intel_epb.html
        for i in $(find /sys/devices/system/cpu/cpu*/power/ -name energy_perf_bias -writable);
        do
          set_and_echo $i 15          
        done

        # https://www.kernel.org/doc/html/latest/admin-guide/pm/intel_pstate.html
        set_and_echo /sys/devices/system/cpu/intel_pstate/energy_efficiency 1
        set_and_echo /sys/devices/system/cpu/intel_pstate/hwp_dynamic_boost 1
        

        set_and_echo /sys/module/snd_hda_intel/parameters/power_save_controller Y
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
