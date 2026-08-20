{ config, lib, pkgs, ... }:

{

  imports = [
    ./battery.nix
    ./inverter.nix
  ];

  services.home-assistant.config = {
    template = [
      {
        sensor = [
          {
            name = "electricity_solar_power";
            unique_id = "electricity_solar_power";
            state = ''
              {% set pv1 = states('sensor.system_house_pv_pv_power_1') | float(0) %}
              {% set pv2 = states('sensor.system_house_pv_pv_power_2') | float(0) %}
              {{ pv1 + pv2 }}
            '';
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