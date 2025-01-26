{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [
          {
            name = "calendar/workday";
            state = ''
              {% set not_holiday_at_home = states('input_boolean.holiday_at_home') | bool(false) == false %}
              {% set workday = (now().weekday() < 5) %}
              {{ not_holiday_at_home and workday }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_workday', 'on') %}
              {% if is_set %}
                mdi:calendar-week
              {% else %}
                mdi:calendar-week-outline
              {% endif %}
            '';
          }
          {
            name = "calendar/weekend";
            state = ''
              {% set holiday_at_home = states('input_boolean.holiday_at_home') | bool(false) %}
              {% set weekend = (now().isoweekday() > 5) %}
              {{ holiday_at_home and weekend }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_weekend', 'on') %}
              {% if is_set %}
                mdi:calendar-weekend
              {% else %}
                mdi:calendar-weekend-outline
              {% endif %}
            '';
          }
          {
            name = "calendar/weekday/evening";
            state = ''
              {{ now().isoweekday() < 6 and 18 <= now().hour < 23 }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_weekday_evening', 'on') %}
              {% if is_set %}
                mdi:calendar-clock
              {% else %}
                mdi:calendar-clock-outline
              {% endif %}
            '';
          }
          {
            name = "calendar/weekday";
            state = ''
              {{ now().isoweekday() < 6 }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_weekday', 'on') %}
              {% if is_set %}
                mdi:calendar-week
              {% else %}
                mdi:calendar-week-outline
              {% endif %}
            '';
          }
        ];
      }
    ];
    
    input_boolean = {
      holiday_at_home = {
        name = "holiday at home";
        icon = "mdi:fireplace";
      };
    };

    recorder = {
      include = {
        entities = [
          "binary_sensor.workday"
          "input_boolean.holiday_at_home"          
        ];

        entity_globs = [
        ];
      };
    };
  };

}
