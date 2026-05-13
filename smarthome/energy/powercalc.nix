{ config, pkgs, lib, ha, ... }:

{

  services.home-assistant.config = {
    powercalc = {
      discovery.enabled = false;
      energy_sensor_naming = "{}_energy";
      power_sensor_naming = "{}_power";
      energy_update_interval = 60;
      sensors = [
        {
          create_group = "electric_heating_auxiliary";
          entities = [
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
              power_sensor_id = "sensor.electric_heating_auxiliary_power";
              energy_sensor_id = "sensor.electric_heating_auxiliary_energy";
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
