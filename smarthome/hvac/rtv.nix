{ config, pkgs, lib, ha, ... }:

let
  rtv = import ../devices/rtv.nix;

in
{

  services.home-assistant.config = {

    template = [
      {
        # Let's boost the RTV temperature to raise the room temperature quicker
        sensor = map
          (v: ha.sensor.temperature
            "${v.floor}/${v.zone}/${v.type}/${v.name} temperature_wanted"
            ''
              {% set room_temp = states('sensor.${v.floor}_${v.zone}_temperature') | float(15.7) %}
              {% set target_temp = states('sensor.${v.floor}_${v.zone}_temperature_auto_wanted') | float(15.7) %}
              {% set need_heating = (room_temp + 0.4) < target_temp %}
              {% set adjustment = 0.5 %}
              {% if need_heating %}
                {% set adjustment = 3 %}
              {% endif %}
              {{ target_temp + adjustment }}
            ''
          )
          rtv;
      }
      {
        sensor = map
          (v: (ha.sensor.battery_from_3v_voltage_attr
            "${v.floor}/${v.zone}/${v.type}/${v.name} battery"
            "climate.${v.floor}_${v.zone}_${v.type}_${v.name}"
          ))
          rtv;
      }
    ];

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
      rtv
    ++
    map
      (v: {
        id = "${v.floor}_${v.zone}_${v.type}_${v.name}_temperature_set";
        alias = "${v.floor}/${v.zone}/${v.type}/${v.name}.temperature_set";
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.${v.floor}_${v.zone}_${v.type}_${v.name}_temperature_wanted";
          }
          {
            platform = "time_pattern";
            minutes = "/10";
          }
        ];
        condition = ''
          {{ 
            (states('sensor.${v.floor}_${v.zone}_${v.type}_${v.name}_temperature_wanted') | float(0) != state_attr('climate.${v.floor}_${v.zone}_${v.type}_${v.name}', 'temperature') | float(0))
          }}
        '';
        action = [
          {
            service = "climate.set_temperature";
            target.entity_id = "climate.${v.floor}_${v.zone}_${v.type}_${v.name}";
            data = {
              temperature = "{{ states('sensor.${v.floor}_${v.zone}_${v.type}_${v.name}_temperature_wanted') }}";
            };
          }
          {
            # Workaround to make sure if it's triggered in quick succession the last one is actually executed.
            delay = "0:01:00";
          }
        ];
        mode = "queued";
      })
      rtv;

    recorder.include = {
      entities = [

      ];
      entity_globs = [
        "sensor.*_*_rtv_*_temperature_wanted"
      ];
    };
  };
}
