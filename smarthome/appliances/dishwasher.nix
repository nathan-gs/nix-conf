{config, pkgs, lib, ha, ...}:
{

  services.home-assistant.config = {
    powercalc.sensors = [
      {
        name = "dishwasher";
        entity_id = "sensor.dummy";
        standby_power = 0.5;
        fixed.power = ''
          {% set remaining_time = states('sensor.dishwasher_remaining_time') | int(0) %}
          {% set program = states('sensor.dishwasher_program') | int(0) %}
          {% set on = states('binary_sensor.dishwasher_status') | bool (false) %}
          {% set power = 0.5 %}
          {% if on %}
            {% if program == 15 %}
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
            {% elif program == 16 %}
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
      }
    ];

    template = [
      { 
        sensor = [
          (
            ha.sensor.energy_demand_remaining 
              "dishwasher" 
              ''states('binary_sensor.dishwasher_status') | bool(false) and states('sensor.dishwasher_remaining_time') | int(0) > 0''
              "0.7"
          )
        ];
      }
    ];

    "automation manual" = [
      (
        ha.automation "system/dishwasher.turn_on"
          {
            triggers = [ (
              ha.trigger.template_for 
                ''
                  {{ 
                  states('binary_sensor.dishwasher_remote_control') | bool(false)
                  and
                  states('binary_sensor.dishwasher_status') | bool(false)
                  and 
                  states('binary_sensor.electricity_demand_management_run_now') | bool(false)
                  }}
                '' 
                "00:05:00"
              ) 
            ];
            actions = [
              {
                service = "hon.start_program";
                data = {
                  program = "auto_universal_soil";
                  parameters = ''{'extraDry':'0','openDoor':'1','delayTime':'0'}'';
                };
                target.device_id = "6522a71c380d6b17f42bffd5b0645999";
              }
            ];
          }
      )
    ];
  };
}
