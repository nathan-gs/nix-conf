{ config, lib, pkgs, ... }:

{

  imports = [
    ./solar
    ./capacity_peaks.nix
    ./demand_management.nix
    ./legacy.nix
    ./powercalc.nix
    ./tariffs.nix
  ];

  services.home-assistant.config.recorder = {
      include = {
        entities = [
          "sensor.battery_discharging_energy"
          "sensor.battery_charging_energy"
          "sensor.energy_electricity_cost"
        ];

        entity_globs = [
          "sensor.electricity*"
          "binary_sensor.electricity*"
          "sensor.dsmr_*"
          "binary_sensor.dsmr_*"
          "sensor.solis_*"
          "binary_sensor.solis_*"
          "sensor.gas_*"
          "sensor.energy_production_*"
          "sensor.solar_*"
        ];
      };
      exclude = {
        entities = [
          "sensor.solar_solis_inverter_cgi"
        ];
        entity_globs = [
          
          "sensor.dsmr_smartgateways_*"
          "binary_sensor.dsmr_smartgateways_*"
        ];
      };
    };

}