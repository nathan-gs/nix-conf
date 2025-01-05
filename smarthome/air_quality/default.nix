{ config, pkgs, lib, ha, ... }:

{
  imports = [
    ./fire_alarm.nix
  ];

  services.home-assistant.config = {

    # Replaced by sos2mqtt
    sensor = [];
    template = [
      
    ];

    recorder = {
      include = {
        entities = [
        ];

        entity_globs = [
          "sensor.system_wtw_air_quality_*_humidity"
          "sensor.system_wtw_air_quality_*_pm25"
          "sensor.system_wtw_air_quality_*_temperature"
          "sensor.system_wtw_air_quality_*_voc_index"
          "sensor.irceline_*"
          "sensor.*_switchbot_*"
          "sensor.*_switchbot"
        ];
      };
    };
  };

}
