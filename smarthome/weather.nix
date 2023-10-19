{ config, lib, pkgs, ... }:

{
  services.home-assistant.config = {

    template = [
      {
        sensor = [
          {
            name = "weather_forecast_temperature_max_4h";
            state = ''
              {% set today = now().date() | string %}
              {% set next_4h = now().hour + 4 %}
              {% set ns = namespace(max_temp = 0.0 | float) %}
              {% for entry in states.weather.openweathermap.attributes.forecast %}
                {% if entry.datetime[:10] == today and (entry.datetime[11:13] | int) < next_4h %}
                  {% if entry.temperature | float > ns.max_temp %}          
                    {% set ns.max_temp = entry.temperature | float %}
                  {% endif %}
                {% endif %}
              {% endfor %}
              {{ ns.max_temp }}
            '';
            device_class = "temperature";
            unit_of_measurement = "°C";
          }
        ];
      }
    ];
  };
}
