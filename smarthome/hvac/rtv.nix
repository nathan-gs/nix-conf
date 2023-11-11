{ config, pkgs, lib, ... }:

let
  rtv = import ./devices/rtv.nix;

in
{

  services.home-assistant.config = {
    "automation manual" = map
      (v: {
        id = "${v.floor}_${v.zone}_${v.type}_${v.name}_temperature_calibration";
        alias = "${v.floor}/${v.zone}/${v.type}/${v.name}.temperature_calibration";
        trigger = [
          {
            platform = "time_pattern";
            minutes = "/15";
          }
        ];
        condition = ''
          {{ states('sensor.${v.floor}_${v.zone}_temperature') != "unknown" }}
        '';
        action = [
          {
            service = "mqtt.publish";
            data = {
              topic = "zigbee2mqtt/${v.floor}/${v.zone}/${v.type}/${v.name}/set";
              payload_template = ''
                {% set sensor_temp = states('sensor.${v.floor}_${v.zone}_temperature') | float(0) %}
                {% set rtv_temp = state_attr('climate.${v.floor}_${v.zone}_rtv_${v.name}', 'local_temperature') | float(0) %}
                {% set rtv_calibration = state_attr('climate.${v.floor}_${v.zone}_rtv_${v.name}', 'local_temperature_calibration') | float(0) %}
                { "local_temperature_calibration": {{ (sensor_temp - (rtv_temp - rtv_calibration))  | round(1) }} }
              '';
            };
          }
        ];
        mode = "single";
      })
      (map (v: v // { type = "rtv"; }) rtv)
      ++
      map
      (v: {
        id = "${v.floor}_${v.zone}_${v.type}_${v.name}_temperature_set";
        alias = "${v.floor}/${v.zone}/${v.type}/${v.name}.temperature_set";
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.${v.floor}_${v.zone}_temperature_auto_wanted";
          }
          {
            platform = "time";
            at = "08:00:00";
          }
          {
            platform = "time";
            at = "13:00:00";
          }
          {
            platform = "time";
            at = "17:00:00";
          }
          {
            platform = "time";
            at = "20:00:00";
          }
          {
            platform = "time";
            at = "23:00:00";
          }
        ];
        condition = ''
          {{ 
            (states('sensor.${v.floor}_${v.zone}_temperature_auto_wanted') | float(0) != state_attr('climate.${v.floor}_${v.zone}_${v.type}_${v.name}', 'temperature') | float(0))
          }}
        '';
        action = [
          {
            service = "climate.set_temperature";
            target.entity_id = "climate.${v.floor}_${v.zone}_${v.type}_${v.name}";
            data = {
              temperature = "{{ states('sensor.${v.floor}_${v.zone}_temperature_auto_wanted') }}";
            };
          }
        ];
        mode = "queued";
      })
      (map (v: v // { type = "rtv"; }) rtv);
  };
}
