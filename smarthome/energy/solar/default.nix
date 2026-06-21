{ config, lib, pkgs, ... }:

{

  imports = [
    ./battery.nix
    ./solis_local.nix
  ];

  services.home-assistant.config = {
    template = [
      {
        sensor = [
          {
            name = "electricity_solar_power";
            unique_id = "electricity_solar_power";
            state = ''
              {% set cgi = states('sensor.solar_currently_produced') | float(none) %}
              {% set cgi_w = (cgi * 1000) if cgi is number else none %}
              {% set cgi_obj = states.sensor.solar_currently_produced %}
              {% set pv1 = states('sensor.solis_dc_power_pv1') | float(none) %}
              {% set pv2 = states('sensor.solis_dc_power_pv2') | float(none) %}
              {% set pv1_obj = states.sensor.solis_dc_power_pv1 %}
              {% set pv2_obj = states.sensor.solis_dc_power_pv2 %}
              {% if pv1 is number and pv2 is number and pv1_obj and pv2_obj %}
                {% set dc_w = pv1 + pv2 %}
                {% set dc_ts = [pv1_obj.last_updated, pv2_obj.last_updated] | min %}
                {% if cgi_w is not none and cgi_obj and cgi_obj.last_updated > dc_ts %}
                  {{ cgi_w }}
                {% else %}
                  {{ dc_w }}
                {% endif %}
              {% else %}
                {{ cgi_w | default(0) }}
              {% endif %}
            '';
            unit_of_measurement = "W";
            attributes.workaround = ''{{ now().minute }}'';
            state_class = "measurement";
          }
        ];
      }
    ];

    recorder.exclude = {
      entities = [
        "device_tracker.solis_s3wifi"
        "device_tracker.smartgatewayp1"
        "automation.battery_change"
      ];
      entity_globs = [
      ];
    };
  };
}