{ config, lib, pkgs, ... }:
let
  carName = config.secrets.nathan-car.name;
in
{

  imports = [
    ./car_charger
  ];

  services.home-assistant.config.recorder = {
      include = {
        entities = [
          "binary_sensor.${carName}_battery_charging"
          "binary_sensor.${carName}_door_lock"
          "binary_sensor.${carName}_plug_status"
          "binary_sensor.${carName}_service"
          "device_tracker.${carName}_position"
          "lock.${carName}_door_lock"
          "sensor.${carName}_average_speed"
          "sensor.${carName}_battery_level"
          "sensor.${carName}_battery_range"
          "sensor.${carName}_fuel_amount"
          "sensor.${carName}_fuel_consumption"
          "sensor.${carName}_fuel_level"
          "sensor.${carName}_odometer"
          "sensor.${carName}_range"
          "sensor.${carName}_time_to_fully_charged"          
        ];

        entity_globs = [
          "binary_sensor.volvo_xc60_"
          "sensor.volvo_xc60_"
        ];
      };
    };
}