{config, pkgs, lib, ...}:

{

  services.home-assistant.config = {
    powercalc = {
      sensors = [
        {
          name = "car_charger_energy";
          entity_id = "binary_sensor.2abn528_battery_charging";
          fixed.power = 1.995;
        }
      ];
    };
  };
}
