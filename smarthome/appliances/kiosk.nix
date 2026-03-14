{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {

    template = [
      {
        sensor = [
          {
            name = "floor0/living/kiosk/window/brightness_target";
            unique_id = "floor0_living_kiosk_window_brightness_target";
            state = ''
              {% set anyone_home = is_state('binary_sensor.anyone_home', 'on') %}
              {% set is_weekday = now().isoweekday() < 6 %}
              {% set holiday_at_home = is_state('input_boolean.holiday_at_home', 'on') %}
              {% set workday = is_weekday and not holiday_at_home %}
              {% set t = now().hour * 60 + now().minute %}
              {% set active_start = 17 * 60 if workday else 8 * 60 %}
              {% set active = t >= active_start and t < (23 * 60 + 30) %}
              {% if anyone_home and active %}
                90
              {% else %}
                5
              {% endif %}
            '';
            icon = "mdi:brightness-6";
          }
        ];
      }
    ];

    "automation manual" = [
      (ha.automation "kiosk/brightness.set"
        {
          triggers = [
            (ha.trigger.state "sensor.floor0_living_kiosk_window_brightness_target")
          ];
          actions = [
            (ha.action.set_value "number.freekiosk_55d9f30c940017af_brightness_control"
              "{{ states('sensor.floor0_living_kiosk_window_brightness_target') | int(1) }}")
          ];
        })
    ];

  };
}
