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
            name = "calendar/night";
            state = ''
              {{ now().hour < 7 or now().hour >= 22 }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_night', 'on') %}
              {% if is_set %}
                mdi:sort-calendar-ascending
              {% else %}
                mdi:sort-calendar-descending
              {% endif %}
            '';
          }
          {
            name = "calendar/weekend";
            state = ''
              {% set weekend = (now().isoweekday() > 5) %}
              {{ weekend }}
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
            name = "calendar/weekend/evening";
            state = ''
              {% set weekend = (now().isoweekday() > 5) %}
              {{ weekend and 18 <= now().hour < 23 }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_weekend_evening', 'on') %}
              {% if is_set %}
                mdi:calendar-weekend
              {% else %}
                mdi:calendar-weekend-outline
              {% endif %}
            '';
          }
          {
            name = "calendar/weekend/morning_and_lunch";
            state = ''
              {% set weekend = (now().isoweekday() > 5) %}
              {{ weekend and 8 <= now().hour < 13 }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_weekend_morning_and_lunch', 'on') %}
              {% if is_set %}
                mdi:calendar-weekend
              {% else %}
                mdi:calendar-weekend-outline
              {% endif %}
            '';
          }
          {
            name = "calendar/weekend/afternoon";
            state = ''
              {% set weekend = (now().isoweekday() > 5) %}
              {{ weekend and 13 < now().hour < 18 }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_weekend_afternoon', 'on') %}
              {% if is_set %}
                mdi:calendar-weekend
              {% else %}
                mdi:calendar-weekend-outline
              {% endif %}
            '';
          }
          {
            name = "calendar/evening";
            state = ''
              {{ now().isoweekday() < 6 and 18 <= now().hour < 23 }}
            '';
            icon = ''
              {% set is_set = is_state('binary_sensor.calendar_evening', 'on') %}
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
          {
            name = "calendar/weekday/day";
            state = ''
              {{ now().isoweekday() < 6 and 8 <= now().hour < 18 }}
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
          "binary_sensor.calendar_*"
        ];
      };
    };
  };

}
