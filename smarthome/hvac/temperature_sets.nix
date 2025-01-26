''
  {% set workday = is_state('binary_sensor.calendar_workday', 'on') %}    
  {% set anyone_home = is_state('binary_sensor.anyone_home', 'on') %}
  {% set temperature_away = 14.5 %}
  {% set temperature_eco = 15.5 %}
  {% set temperature_night = 16 %}
  {% set temperature_comfort_low = 17.5 %}
  {% set temperature_comfort = 19 %}
  {% set temperature_minimal = 5.5 %}
''