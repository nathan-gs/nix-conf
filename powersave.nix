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
        # https://wiki.archlinux.org/title/Power_management
        for i in $(find /sys/devices/system/cpu/cpufreq/policy? -name energy_performance_preference -writable);
        do
          original="$(cat $i)" 
          echo 'power' > $i || true
          current="$(cat $i)"
          echo "Changing $i from $original to $current"
        done

        ${pkgs.cpupower}/bin/cpupower set --perf-bias 15

        echo Y > /sys/module/snd_hda_intel/parameters/power_save_controller 
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

  boot.blacklistedKernelModules = [ "bluetooth" "iwlwifi" ];
#  services.thermald.enable = true;


}
