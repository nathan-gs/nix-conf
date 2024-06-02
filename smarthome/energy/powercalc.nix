{ config, pkgs, lib, ha, ... }:

{

  services.home-assistant.config = {
    powercalc = {
      enable_autodiscovery = false;
      energy_sensor_naming = "{}_energy";
      power_sensor_naming = "{}_power";
      force_update_frequency = "00:01:00";
      sensors = [
        {
          create_group = "electric_heating_auxiliary";
          entities = [
            {
              entity_id = "sensor.dummy";
              name = "electric_heating_auxiliary_dummy";
              fixed.power = 0;
            }
            {
              power_sensor_id = "sensor.floor0_living_metering_plug_verwarming_power";
              energy_sensor_id = "sensor.floor0_living_metering_plug_verwarming_energy";
            }
            {
              power_sensor_id = "sensor.floor0_bureau_metering_plug_verwarming_power";
              energy_sensor_id = "sensor.floor0_bureau_metering_plug_verwarming_energy";
            }
            {
              power_sensor_id = "sensor.floor1_nikolai_metering_plug_verwarming_power";
              energy_sensor_id = "sensor.floor1_nikolai_metering_plug_verwarming_energy";
            }
          ];
        }
        {
          create_group = "electric_heating";
          entities = [
            {
              entity_id = "sensor.electric_heating_auxiliary";
            }
            {
              power_sensor_id = "sensor.floor1_badkamer_metering_plug_verwarming_power";
              energy_sensor_id = "sensor.floor1_badkamer_metering_plug_verwarming_energy";
            }
            {
              power_sensor_id = "sensor.system_wtw_metering_plug_verwarming_power";
              energy_sensor_id = "sensor.system_wtw_metering_plug_verwarming_energy";
            }
          ];
        }
      ];
    };
  };
}
