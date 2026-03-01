{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [
          {
            name = "calendar/workday";
            unique_id = "calendar_workday";
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
            unique_id = "calendar_night";
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
            unique_id = "calendar_weekend";
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
            unique_id = "calendar_weekend_evening";
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
            unique_id = "calendar_weekend_morning_and_lunch";
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
            unique_id = "calendar_weekend_afternoon";
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
            unique_id = "calendar_evening";
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
            unique_id = "calendar_weekday";
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
            unique_id = "calendar_weekday_day";
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
    
  };

}
