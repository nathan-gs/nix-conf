{ config, pkgs, lib, ha, ... }:
{
  services.home-assistant.config = {
    # RHI-5K-48ES-5G. Marketing says fanless / natural convection — that is
    # no *external* fan. The Hybrid 5G has a small internal fan that comes
    # on under load (audible zoom; also in the temp curve: internal °C drops
    # while PV is still rising, typically once the sensor is past ~45–50 °C).
    #
    # Always-on EMS, HF-isolated battery path. Datasheet: max >97.5 %,
    # EU >96.8 %. Night ΔT vs basement is 9.5–10.2 K every month → ~54 W
    # idle at 5.6 W/K. Above ~44 °C we blend toward 1.6× W/K (forced air)
    # so a fan-cooled ΔT is not read as a drop in dissipation.
    input_number.electricity_inverter_w_per_k = {
      name = "electricity/inverter/w_per_k";
      min = 2;
      max = 12;
      step = 0.1;
      mode = "box";
      unit_of_measurement = "W/K";
      icon = "mdi:thermometer";
      initial = 5.6;
    };

    powercalc.sensors = [
      {
        name = "electricity/inverter";
        unique_id = "electricity_inverter";
        entity_id = "sensor.solis_temperature";
        fixed.power = ''
          {% set t_inv = states('sensor.solis_temperature') | float(none) %}
          {% set t_amb = states('sensor.basement_basement_temperature') | float(none) %}
          {% set w_nat = states('input_number.electricity_inverter_w_per_k') | float(5.6) %}
          {% if t_inv is number and t_amb is number %}
            {# 0 at 44 °C → 1 at 50 °C: internal fan ramp #}
            {% set fan = ([0.0, t_inv - 44, 6.0] | sort)[1] / 6 %}
            {% set w_per_k = w_nat * (1 + 0.6 * fan) %}
            {{ [((t_inv - t_amb) * w_per_k), 0] | max | round(0) }}
          {% endif %}
        '';
      }
    ];
  };
}
