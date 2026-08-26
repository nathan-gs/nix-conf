{ config, lib, pkgs, ... }:

{

  imports = [
    ./battery.nix
    ./inverter.nix
    ./pylontech.nix
  ];

  services.home-assistant.config = {
    template = [
      {
        sensor = [
          {
            name = "electricity_solar_power";
            unique_id = "electricity_solar_power";
            state = "{{ states('sensor.system_house_pv_total_pv_power') | float(0) }}";
            unit_of_measurement = "W";
            state_class = "measurement";
          }
        ];
      }
    ];

    recorder.exclude = {
      entities = [
        "device_tracker.solis_s3wifi"
        "device_tracker.smartgatewayp1"
        "automation.battery_change"
      ];
      entity_globs = [
      ];
    };
  };
}