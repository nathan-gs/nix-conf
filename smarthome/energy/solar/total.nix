{ config, pkgs, lib, ha, ... }:
{
  # Reconstructs a high-precision, never-resetting lifetime PV total from the
  # Modbus daily counter (system_house_pv_pv_today_energy_generation, 1 decimal,
  # resets at local midnight) instead of the inverter's own lifetime total
  # register (system_house_pv_pv_total_energy_generation, whole kWh only).
  #
  # Pattern carried over from the retired solis_local.nix .cgi scrape
  # (solar_delivery_total / _till_yesterday): a trigger sensor snapshots the
  # running total at midnight, and the running total itself is
  # till_yesterday + today. Frozen 23:00-03:00 because the original .cgi
  # sensor briefly re-reported the previous day's total for hours after
  # midnight; kept as a precaution even though the Modbus register hasn't
  # shown the same quirk yet.
  #
  # `solar/total_energy_generation` is the sum across inverters (today just
  # the one house plant) - this is the entity the Energy dashboard should
  # point at. Add a second `solar/<name>/total_energy_generation` +
  # `_till_yesterday` pair here and extend the sum when a second inverter
  # shows up.
  services.home-assistant.config = {
    template = [
      {
        trigger = ha.trigger.at "00:00:00";
        sensor = [
          {
            name = "solar/house/total_till_yesterday";
            unique_id = ha.genId "solar/house/total_till_yesterday";
            state = "{{ states('sensor.solar_house_total_energy_generation') | float(0) }}";
            unit_of_measurement = "kWh";
            device_class = "energy";
            icon = "mdi:solar-panel";
            state_class = "total";
          }
        ];
      }
      {
        sensor = [
          {
            name = "solar/house/total_energy_generation";
            unique_id = ha.genId "solar/house/total_energy_generation";
            state = ''
              {% set hour = now().hour %}
              {% set till_yesterday = states('sensor.solar_house_total_till_yesterday') | float(0) %}
              {% set today = states('sensor.system_house_pv_pv_today_energy_generation') | float(0) %}
              {% set previous = states('sensor.solar_house_total_energy_generation') | float(0) %}
              {% if hour < 3 or hour >= 23 %}
                {{ previous }}
              {% else %}
                {{ till_yesterday + today }}
              {% endif %}
            '';
            unit_of_measurement = "kWh";
            device_class = "energy";
            icon = "mdi:solar-panel";
            state_class = "total_increasing";
          }
          {
            name = "solar/total_energy_generation";
            unique_id = ha.genId "solar/total_energy_generation";
            state = "{{ states('sensor.solar_house_total_energy_generation') | float(0) }}";
            unit_of_measurement = "kWh";
            device_class = "energy";
            icon = "mdi:solar-panel";
            state_class = "total_increasing";
          }
        ];
      }
    ];
  };
}
