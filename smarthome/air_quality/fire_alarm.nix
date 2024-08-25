{ config, pkgs, lib, ha, ... }:

{

  services.home-assistant.config = {
    
    sensor = [];
    template = [
      
    ];

    recorder = {
      include = {
        entity_globs = [
          "binary_sensor.*_*_fire_alarm_*_smoke"
          "sensor.*_*_fire_alarm_*_aqi"
          "sensor.*_*_fire_alarm_*_co2"
          "sensor.*_*_fire_alarm_*_siren_state"
          "sensor.*_*_fire_alarm_*_voc"
        ];
      };
      exclude = {
        entity_globs = [
          "*.*_*_fire_alarm_*"
        ];
      };
    };
  };

}
