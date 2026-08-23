{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {

    template = [
      {
        sensor = [
          #
          # https://www.home-assistant.io/integrations/weather#service-weatherget_forecasts
          # {
          #   name = "weather_forecast_temperature_max_4h";
          #   state = ''
          #     {#
          #     {% set today = now().date() | string %}
          #     {% set next_4h = now().hour + 4 %}
          #     {% set ns = namespace(max_temp = 0.0 | float) %}
          #     {% for entry in states.weather.openweathermap.attributes.forecast %}
          #       {% if entry.datetime[:10] == today and (entry.datetime[11:13] | int) < next_4h %}
          #         {% if entry.temperature | float > ns.max_temp %}
          #           {% set ns.max_temp = entry.temperature | float %}
          #         {% endif %}
          #       {% endif %}
          #     {% endfor %}
          #     {{ ns.max_temp }}
          #     #}
          #     0.0
          #   '';
          #   device_class = "temperature";
          #   unit_of_measurement = "°C";
          #   state_class = "measurement";
          # }
        ];
      }
      {
        # Tomorrow's forecasted daily high, refreshed nightly. Consumed by the
        # WTW ventilation logic to hold off the bypass-driven "high" stand on
        # mild days where pre-cooling the house isn't needed.
        trigger = [ { trigger = "time"; at = "21:15:00"; } ];
        action = [
          {
            service = "weather.get_forecasts";
            target.entity_id = "weather.sxw";
            data.type = "daily";
            response_variable = "fc";
          }
        ];
        sensor = [
          (ha.sensor.temperature "weather/tomorrow/temperature.max" ''
            {% set t = (now() + timedelta(days=1)).date() %}
            {% set ns = namespace(val=30.0) %}
            {% for f in fc['weather.sxw'].forecast %}
              {% if as_datetime(f.datetime).date() == t %}{% set ns.val = f.temperature | float(30) %}{% endif %}
            {% endfor %}
            {{ ns.val }}
          '')
        ];
      }
    ];

    sensor = [
      {
        platform = "statistics";
        name = "rainfall_5d";
        entity_id = "sensor.openweathermap_forecast_precipitation";
        state_characteristic = "total";
        max_age.hours = 24 * 5;
        sampling_size = 60 * 24 * 5;
      }
    ];
  };
}
