{ config, pkgs, lib, ha, ... }:

{
  # Shared powercalc behaviour for every sensor in this config. The sensors
  # themselves live with the device that owns them; the heating groups are in
  # smarthome/hvac/electric_heating.nix.
  services.home-assistant.config = {
    powercalc = {
      discovery.enabled = false;
      energy_sensor_naming = "{}_energy";
      power_sensor_naming = "{}_power";
      energy_update_interval = 60;
    };
  };
}
