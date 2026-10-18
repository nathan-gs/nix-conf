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
        # Forecasted daily highs, refreshed hourly (and on HA startup).
        # Tomorrow's is consumed by the WTW ventilation logic to hold off the
        # bypass-driven "high" stand on mild days where pre-cooling the house
        # isn't needed.
        triggers = [
          { trigger = "time_pattern"; hours = "/1"; }
          { trigger = "homeassistant"; event = "start"; }
        ];
        actions = [
          {
            action = "weather.get_forecasts";
            target.entity_id = "weather.sxw";
            data.type = "daily";
            response_variable = "fc";
          }
        ];
        sensor = [
          # Today's forecasted daily high. Replaces the forecast sensors the
          # openweathermap integration no longer creates; the CV setpoint logic
          # compares it against the target temperature.
          (ha.sensor.temperature "weather/today/temperature.max" ''
            {% set fc_days = fc['weather.sxw'].forecast %}
            {% set ns = namespace(val=fc_days[0].temperature | float(15)) %}
            {% for f in fc_days %}
              {% if as_datetime(f.datetime).date() == now().date() %}{% set ns.val = f.temperature | float(15) %}{% endif %}
            {% endfor %}
            {{ ns.val }}
          '')
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
      # Observed rain (mm/h) accumulated into a running mm counter. The
      # openweathermap integration no longer exposes forecast sensors, and
      # summing forecast samples never measured rainfall anyway.
      # max_sub_interval keeps it ticking while the rate sits at 0, so a shower
      # is integrated from when it started rather than from the next change.
      {
        platform = "integration";
        name = "weather/rain.total";
        unique_id = ha.genId "weather/rain.total";
        source = "sensor.openweathermap_rain";
        method = "left";
        unit_time = "h";
        round = 2;
        max_sub_interval.minutes = 5;
      }
      # Rain fallen over the last 5 days. keep_last_sample stops a dry week
      # (the counter never changes, so no samples arrive) from emptying the
      # buffer and going unknown instead of reporting 0.
      {
        platform = "statistics";
        name = "rainfall_5d";
        entity_id = "sensor.${ha.genId "weather/rain.total"}";
        state_characteristic = "change";
        max_age.hours = 24 * 5;
        keep_last_sample = true;
        sampling_size = 12 * 24 * 5;
      }
    ];
  };
}
