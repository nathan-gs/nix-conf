{ config, lib, pkgs, ha, ... }:
{
  services.home-assistant.config = {
    mqtt = {
      binary_sensor = [
        {
          name = "watermeter_leak_detect";
          unique_id = "watermeter_leak_detect";
          state_topic = "watermeter/reading/leak_detect";
          device_class = "problem";
          payload_on = "true";
          payload_off = "false";
        }
      ];

      sensor = [
        {
          name = "watermeter_total";
          state_topic = "watermeter/reading/current_value";
          unique_id = "watermeter_total";
          state_class = "total_increasing";
          unit_of_measurement = "L";
          device_class = "water";
          force_update = true;
          # Device can go quiet for long stretches; align with stale_entities max_age (10h).
          expire_after = 36000;
          icon = "mdi:water";
        }
        {
          name = "watermeter_usage_last_minute";
          state_topic = "watermeter/reading/water_used_last_minute";
          unit_of_measurement = "L";
          icon = "mdi:water";
          unique_id = "watermeter_usage_last_minute";
          state_class = "measurement";
          expire_after = 36000;
        }
      ];

    };

    utility_meter = {
      water_delivery = {
        source = "sensor.watermeter_total";
      };
      water_delivery_hourly = {
        source = "sensor.watermeter_total";
        cycle = "hourly";
      };
      water_delivery_daily = {
        source = "sensor.watermeter_total";
        cycle = "daily";
      };
      water_delivery_weekly = {
        source = "sensor.watermeter_total";
        cycle = "weekly";
      };
      water_delivery_monthly = {
        source = "sensor.watermeter_total";
        cycle = "monthly";
      };
      water_delivery_yearly = {
        source = "sensor.watermeter_total";
        cycle = "yearly";
      };
    };

    template = [
      {
        sensor = [
          {
            name = "water_cost";
            unique_id = "water_cost";
            unit_of_measurement = "€/L";
            # Gent / Farys + AquaRio, integral price excl. 6% BTW (VMM 01/06/2026):
            # basis 6.6649 €/m³ = drink 3.0058 + gem.san. 1.9572 + bovengem. 1.7019
            # comfort 11.6279 €/m³ = drink 6.0116 + gem.san. 3.9144 + bovengem. 3.4038
            # First 30 m³/wooneenheid + 30 m³/gedomicilieerde at base (1+4 → 150 m³)
            # https://www.farys.be/nl/watertarieven
            # https://vmm.vlaanderen.be/feiten-cijfers/water/waterfactuur/tarieven-kraanwater-voor-gezinnen
            state = ''
              {% if states('sensor.water_delivery_yearly') | float(0) > ((1 * 30 + 4 * 30) * 1000) %}
              {{ (11.6279 / 1000) * 1.06 }}
              {% else %}
              {{ (6.6649 / 1000) * 1.06 }}
              {% endif %}
            '';
            state_class = "measurement";
          }
          {
            # Farys vastrecht drinkwater: 50 €/year/wooneenheid excl. 6% BTW, −20% per
            # gedomicilieerde (max 5). Same household as water_cost: 1 wooneenheid, 4 persons.
            # https://www.farys.be/nl/tariefstructuur
            name = "water_cost_monthly_fixed";
            unique_id = "water_cost_monthly_fixed";
            unit_of_measurement = "€";
            state_class = "measurement";
            icon = "mdi:water";
            state = ''
              {% set wooneenheden = 1 %}
              {% set gedomicilieerden = 4 %}
              {% set vastrecht_excl = 50 * wooneenheden %}
              {% set discount = [1.0, 0.2 * ([gedomicilieerden, 5] | min)] | min %}
              {% set yearly_incl = vastrecht_excl * (1 - discount) * 1.06 %}
              {{ (yearly_incl / 12) | round(5) }}
            '';
          }
          {
            name = "water_cost_daily_fixed";
            unique_id = "water_cost_daily_fixed";
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "measurement";
            icon = "mdi:calendar-today";
            state = ''
              {% set monthly = states('sensor.water_cost_monthly_fixed') | float(0) %}
              {% set last_day = (now().replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1) %}
              {{ (monthly / last_day.day) | round(5) }}
            '';
          }
          {
            # Dummy 0 L so Energy can attach fixed-cost totals (same pattern as elec/gas).
            name = "water_fixed_cost_volume";
            unique_id = "water_fixed_cost_volume";
            unit_of_measurement = "L";
            device_class = "water";
            state_class = "total";
            icon = "mdi:cash-clock";
            state = "0";
          }
        ];
      }
      # Accrue daily fixed water cost for the Energy dashboard (mirrors elec/gas in tariffs.nix).
      # - 00:00: add today's daily fixed once (day already includes fixed cost)
      # - start / daily_fixed available: seed month-to-date incl. today if still 0
      {
        trigger = [
          { platform = "time"; at = "00:00:00"; id = "accrue"; }
          {
            platform = "homeassistant";
            event = "start";
            id = "seed";
          }
          {
            platform = "state";
            entity_id = "sensor.water_cost_daily_fixed";
            id = "seed";
          }
        ];
        sensor = [
          {
            name = "water_fixed_cost_total";
            unique_id = "water_fixed_cost_total";
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total_increasing";
            icon = "mdi:cash-clock";
            state = ''
              {% set daily = states('sensor.water_cost_daily_fixed') | float(0) %}
              {% set prev = this.state | float(0) if this.state not in ['unknown', 'unavailable', 'none'] else 0 %}
              {% if trigger.id == 'accrue' %}
                {{ (prev + daily) | round(5) }}
              {% elif prev == 0 and daily > 0 %}
                {{ (daily * now().day) | round(5) }}
              {% else %}
                {{ prev }}
              {% endif %}
            '';
          }
        ];
      }
    ];

    "automation manual" = [
      (ha.automation "system/water.leak_detected" {
        triggers = [(ha.trigger.on "binary_sensor.watermeter_leak_detect")];
        actions = [(ha.action.notify "Waterlek" "Waterlek gedetecteerd, verbruik van {{ states('sensor.watermeter_usage_last_minute') | float(0) | round(0) }}l in laatste minuut.")];
      })
      (ha.automation "system/water.abnormal_usage" {
        triggers = [(ha.trigger.above "sensor.water_delivery_daily" 500)];
        actions = [(ha.action.notify "Abnormaal Waterverbruik" "Abnormaal dagelijks waterverbruik, reeds {{ states('sensor.water_delivery_daily') | float(0) | round(0) }}l verbruikt.")];
      })
    ];


  };
}
