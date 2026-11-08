{ config, lib, pkgs, ha, ... }:

# Keeps the Itho HRU 350's temperature setpoints honest despite its intake
# NTC reading ~2-3 °C warm (measured 2026-11: +2.2 °C mean against
# sensor.outdoor_temperature, ~+2.9 °C near freezing; the room NTC is within
# 0.5 °C and needs nothing). The unit has no sensor-offset setting and the
# add-on cannot inject a temperature, so instead the setpoints that are
# compared against that NTC are shifted by the tracked offset:
#
#   itho reading = true temperature - offset   (offset = outdoor - raw, < 0)
#   setpoint     = wanted true temperature - offset
#
# The offset grows as it gets colder, and a 7-day average follows the
# season: in winter it is learned at winter temperatures, which is when the
# frost setpoint matters, and in summer at summer temperatures, which is
# when the summer-day counter matters.
#
# Writes go through the add-on's REST API, which only accepts indexes listed
# under System > "Activate settings indexes". 1 and 10 must be in that list;
# a rejected write just leaves the readback sensor showing the old value.

let
  host = "http://wtw-itho.l.nathan.gs";

  # Itho setting index -> the true temperature it should trigger at.
  setpoints = [
    {
      index = 1;
      key = "frost_temperature";
      # Roughly what the factory 3.5 °C setpoint already amounted to with
      # the biased NTC, so the unit itself behaves as before; what changes
      # is that the pre-heater (electric_heating.nix) now starts 0.5 °C
      # above this, i.e. before frost protection instead of at ~-3 °C.
      want = 1.0;
      min = 0;
      max = 7;
    }
    {
      index = 10;
      key = "summer_temperature";
      want = 19.0;
      min = 15;
      max = 25;
    }
  ];
in
{
  services.home-assistant.config = {

    sensor = [
      {
        # Time-weighted, so the many updates during a fast-changing hour
        # do not outweigh a long steady night.
        platform = "statistics";
        name = "itho_wtw_inlet_temperature_offset";
        unique_id = "itho_wtw_inlet_temperature_offset";
        entity_id = "sensor.itho_wtw_inlet_temperature_correction";
        state_characteristic = "average_step";
        max_age.days = 7;
        sampling_size = 20000;
        keep_last_sample = true;
        precision = 2;
      }
    ];

    rest = map (s: {
      resource = "${host}/api/v2/settings?index=${toString s.index}";
      scan_interval = 3600;
      sensor = [
        {
          name = "itho_wtw_setting_${s.key}";
          unique_id = "itho_wtw_setting_${s.key}";
          value_template = "{{ value_json.data.current }}";
          unit_of_measurement = "°C";
          device_class = "temperature";
          icon = "mdi:thermometer-lines";
        }
      ];
    }) setpoints;

    rest_command.itho_wtw_setting = {
      url = "${host}/api/v2/settings";
      method = "put";
      content_type = "application/json";
      payload = ''{"index": {{ index }}, "value": {{ value }}}'';
    };

    "automation manual" = [
      (ha.automation "itho_wtw/temperature_setpoints" {
        triggers = [
          (ha.trigger.at "03:30:00")
          {
            trigger = "homeassistant";
            event = "start";
          }
        ];
        conditions = [
          # Sanity band: a broken outdoor sensor must not drag the frost
          # setpoint around. Measured offsets are -1 to -3.
          (ha.condition.template ''
            {% set o = states('sensor.itho_wtw_inlet_temperature_offset') | float(none) %}
            {{ o is not none and -5 < o < 1 }}
          '')
        ];
        actions = [
          # Let the rest sensors poll once after a restart.
          { delay.minutes = 2; }
          {
            repeat.for_each = map (s: {
              inherit (s) index key want min max;
            }) setpoints;
            repeat.sequence = [
              {
                variables = {
                  offset = "{{ states('sensor.itho_wtw_inlet_temperature_offset') | float }}";
                  # Half-degree steps: finer than the NTC can be trusted,
                  # and it keeps EEPROM writes to the odd day.
                  target = ''
                    {% set t = ((repeat.item.want - offset) * 2) | round(0) / 2 %}
                    {{ [repeat.item.max, [repeat.item.min, t] | max] | min }}
                  '';
                  current = "{{ states('sensor.itho_wtw_setting_' ~ repeat.item.key) | float(none) }}";
                };
              }
              {
                "if" = [
                  (ha.condition.template ''{{ current is none or (target | float - current) | abs >= 0.5 }}'')
                ];
                "then" = [
                  {
                    service = "rest_command.itho_wtw_setting";
                    data = {
                      index = "{{ repeat.item.index }}";
                      value = "{{ target }}";
                    };
                  }
                  {
                    service = "homeassistant.update_entity";
                    target.entity_id = "{{ 'sensor.itho_wtw_setting_' ~ repeat.item.key }}";
                  }
                ];
              }
            ];
          }
        ];
      })
    ];
  };
}
