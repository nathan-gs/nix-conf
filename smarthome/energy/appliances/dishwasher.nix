{config, pkgs, lib, ...}:

{

  services.home-assistant.config = {
    powercalc.sensors = [
      {
        name = "dishwasher_energy";
        entity_id = "binary_sensor.dishwasher_status";
        power_sensor_id = "sensor.dishwasher_power";
        force_energy_sensor_creation = true;
        standby_power = 0.5;
      }
    ];

    template = [
      { 
        sensor = [
          {
            name = "dishwasher_power";
            state = ''
              {% set remaining_time = states('sensor.dishwasher_remaining_time') | int(0) %}
              {% set program = states('sensor.dishwasher_program') %}
              {% set mode = states('sensor.dishwasher_mode') %}
              {% set on = states('binary_sensor.dishwasher_status') | bool (false) %}
              {% set power = 0.5 %}
              {% if on %}
                {% if program == 15 and mode == "Program 2" %}
                  {# Programma Universeel #}
                  {% if remaining_time > 170 %}
                    {% set power = 0.5 %}
                  {% elif remaining_time > 162 %}
                    {% set power = 40 %}
                  {% elif remaining_time > 157 %}
                    {% set power = 2000 %}
                  {% elif remaining_time > 152 %}
                    {% set power = 40 %} 
                  {% elif remaining_time > 147 %}
                    {% set power = 2000 %}
                  {% elif remaining_time > 135 %}
                    {% set power = 20 %}
                  {% elif remaining_time > 132 %}
                    {% set power = 2000 %}
                  {% elif remaining_time > 84 %}
                    {% set power = 20 %}
                  {% elif remaining_time > 79 %}
                    {% set power = 2000 %}
                  {% else %}
                    {% set power = 5 %}
                  {% endif %}
                {% elif program == 16 and mode == "Program 2" %}
                  {# Programma Auto #}
                  {% if remaining_time > 160 %}
                    {% set power = 0.5 %}
                  {% elif remaining_time > 146 %}
                    {% set power = 40 %}
                  {% elif remaining_time > 142 %}
                    {% set power = 2000 %}
                  {% elif remaining_time > 137 %}
                    {% set power = 40 %} 
                  {% elif remaining_time > 131 %}
                    {% set power = 2000 %}
                  {% elif remaining_time > 119 %}
                    {% set power = 20 %}
                  {% elif remaining_time > 117 %}
                    {% set power = 2000 %}
                  {% elif remaining_time > 87 %}
                    {% set power = 20 %}
                  {% elif remaining_time > 79 %}
                    {% set power = 2000 %}
                  {% else %}
                    {% set power = 5 %}
                  {% endif %}
                {% else %}
                {% endif %}
              {% endif %}
              {{ power }}
            '';
            unit_of_measurement = "W";
            icon = ''
              {% if states('sensor.dishwasher_power') > 1 %}
                mdi:dishwasher
              {% else %}
                mdi:dishwasher-off
              {% endif %}
          '';
          }
        ];
      }
    ];
  };
}
