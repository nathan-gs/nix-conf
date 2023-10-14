{config, pkgs, lib, ...}:

{

  services.home-assistant.config = {
    powercalc = {
      enable_autodiscovery = false;
      energy_sensor_naming = "{}_energy";
      power_sensor_naming = "{}_power";

      sensors = [
      ];
    };
  };
}
