''
  {% set workday = states('binary_sensor.workday') | bool(true) %}    
  {% set anyone_home = states('binary_sensor.anyone_home') | bool(true) %}
  {% set temperature_away = 14.5 %}
  {% set temperature_eco = 16 %}
  {% set temperature_night = 17 %}
  {% set temperature_comfort_low = 17.5 %}
  {% set temperature_comfort = 19 %}
  {% set temperature_minimal = 5.5 %}
''