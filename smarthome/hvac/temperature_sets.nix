''
  {% set workday = is_state('binary_sensor.calendar_workday', 'on') %}    
  {% set anyone_home = is_state('binary_sensor.anyone_home', 'on') %}
  {% set anyone_home_or_coming = is_state('binary_sensor.anyone_home_or_coming_home', 'on') %}
  {% set far_away = is_state('binary_sensor.far_away', 'on') %}
  {% set temperature_away = 15 %}
  {% set temperature_eco = 15.5 %}
  {% set temperature_night = 16 %}
  {% set temperature_comfort_low = 17.5 %}
  {% set temperature_comfort = 19.5 %}
  {% set temperature_minimal = 5.5 %}
  {% set temperature_heating_threshold = 0.4 %}
  {% set temperature_max = 21.5 %}
''