{config, pkgs, ...}:

{

  template = [
    {
      binary_sensor = [
        {
          name = "system_carcharger_can_load";
          device_class = "plug";
          icon = ''
          {% if states('binary_sensor.system_carcharger_can_load') %}
          mdi:car-electric
          {% else %}
          mdi:car-electric-outline
          {% endif %}
          '';
          state = ''
            {% set solar_remaining = states('sensor.energy_production_today_remaining') | float(0)  %}
            {% set battery_remaining = states('sensor.solis_remaining_battery_capacity') | float(0) %}
            {% set car_charged = states('sensor.2abn528_battery_level') | float(10) %}
            {% set solar_now = states('sensor.solar_currently_produced') | float(0) %}
            {% set current_usage = states('sensor.electricity_total_power') | float(5) / 1000 %}
            {% set charger_in_use = states('switch.garden_garden_plug_laadpaal') | bool(false) %}
            {% set charger_consumption = 2.2 %}
            {#
            {% set solar_remaining = 8.1  %}
            {% set solar_now = 2.6 | float(0) %}
            {% set current_usage = 3.0 %}
            {% set charger_in_use = true %}
            #}
            {# calculations #}
            {% set car_kwh_needed = ((11 * (100 - car_charged))/100) %}
            {% set battery_needed = (5 * (100 - battery_remaining))/100 %}
            {% set house_needed = 0.3 * (24 - now().hour) %}
            {% set total_needed = house_needed + car_kwh_needed + battery_needed %}
            {% set production_needed = current_usage + charger_consumption %}
            {% if charger_in_use %}
            {% set production_needed = production_needed - charger_consumption %}
            {% endif %}
            {#
            {{ current_usage }}kWh
            {{ solar_remaining }}kWh
            {{ battery_remaining }}%
            {{ solar_now }} kW
            {{ car_charged }}%
            {{ car_kwh_needed}}kWh
            {{ battery_needed }}kWH
            {{ total_needed }}kWh
            {{ production_needed }}kW
            #}
            {% if solar_now > production_needed %}
              {% if solar_remaining > total_needed %}
                true
              {% else %}
                false
              {% endif %}
            {% else %}
              false
            {% endif %}
          '';
        }
      ];
    }
    
  ];
  sensor = [
  ];

  mqtt_sensor =  [
  ];

  utility_meter = {};
  customize = {};

  automations = [
  ];
  binary_sensor = [];

  recorder_excludes = [
  ];
}