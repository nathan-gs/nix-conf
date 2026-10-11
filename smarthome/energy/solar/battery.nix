{ config, pkgs, lib, ha, ... }:
let
  # Signed battery power: negative while charging, positive while
  # discharging. Do not use inverter DC power 33149
  # (`system_house_pv_battery_power_net`) — that shunt sits ~70 W toward
  # discharge at idle (overnight ~130 W vs ~55 W actual), which is why
  # Solis lifetime charge/discharge kWh and the Riemann totals ran at
  # ~130% discharge/charge. BMS current (33142, CAN from the Pylontech
  # stack) matches the pack console; pair with BMS voltage and the
  # direction bit (33135).
  electricityBatteryPower = {
    name = "electricity_battery_power";
    unique_id = "electricity_battery_power";
    state = ''
      {% set current = states('sensor.system_house_pv_battery_current_bms') | float(0) | abs %}
      {% set voltage = states('sensor.system_house_pv_battery_voltage_bms') | float(0) %}
      {% set discharging = states('sensor.system_house_pv_battery_current_direction') | int(1) == 1 %}
      {% set power = (current * voltage) | round(0) %}
      {{ power if discharging else -power }}
    '';
    availability = ''
      {{ states('sensor.system_house_pv_battery_current_bms') not in ['unknown', 'unavailable', 'none']
         and states('sensor.system_house_pv_battery_voltage_bms') not in ['unknown', 'unavailable', 'none']
         and states('sensor.system_house_pv_battery_current_direction') not in ['unknown', 'unavailable', 'none'] }}
    '';
    unit_of_measurement = "W";
    state_class = "measurement";
    # HA suppresses state_changed events when the new state+attributes
    # exactly match the old ones — even on a periodic trigger re-render.
    # `force_update` would fix that, but it's not a valid key on the modern
    # `template:` schema (HA rejects the whole block with it set, which
    # silently dropped this sensor entirely on 2026-08-30). So carry an
    # attribute that changes on every render instead, guaranteeing a fresh
    # event at least once a minute (via the time_pattern trigger below) even
    # when the computed power is unchanged — so the Riemann integration
    # further down never has to interpolate across a long silent gap.
    # Without this: a 72-minute silent gap plus one 3.7kW transient produced
    # a false 2.25kWh step in the discharge total on 2026-08-30.
    attributes.last_render = "{{ now().isoformat() }}";
  };

  # Split the signed power into two always-nonnegative sensors and
  # Riemann-integrate each separately (HA core `integration` platform)
  # rather than trusting the Solis lifetime charge/discharge registers
  # (33161–33168), which accumulate from the biased 33149 shunt. The
  # Modbus poll is 10s, so trapezoidal tracks real power swings. The
  # `integration` sensor restores its accumulated state across HA
  # restarts natively (RestoreEntity).
  mkBatteryPowerSplit = { name, icon, isCharge }:
    let
      sign = if isCharge then "-1" else "1";
    in {
      name = "${name}_power";
      unique_id = ha.genId "${name}_power";
      icon = icon;
      state = ''
        {% set battery_power = states('sensor.electricity_battery_power') | float(0) %}
        {% set power = ${sign} * battery_power %}
        {{ [power, 0] | max }}
      '';
      device_class = "power";
      unit_of_measurement = "W";
      state_class = "measurement";
      # Propagate the parent's heartbeat: this is a legacy (non-trigger)
      # template that re-renders whenever electricity_battery_power fires a
      # state_changed event — including its minutely same-value heartbeat —
      # but a same-value recompute here would itself get suppressed by HA's
      # identical-state dedup unless it also carries a changing attribute.
      attributes.last_render = "{{ now().isoformat() }}";
    };

  batteryChargingPower = mkBatteryPowerSplit {
    name = "battery/house/charging";
    icon = "mdi:battery-plus";
    isCharge = true;
  };
  batteryDischargingPower = mkBatteryPowerSplit {
    name = "battery/house/discharging";
    icon = "mdi:battery-minus";
    isCharge = false;
  };

  mkBatteryEnergyIntegral = { name, icon, source }: {
    platform = "integration";
    name = name;
    unique_id = ha.genId name;
    source = "sensor.${ha.genId source}";
    method = "trapezoidal";
    unit_time = "h";
    unit_prefix = "k";
  };

  batteryHouseChargeTotal = mkBatteryEnergyIntegral {
    name = "battery/house/charge_total_energy";
    icon = "mdi:battery-plus";
    source = batteryChargingPower.name;
  };
  batteryHouseDischargeTotal = mkBatteryEnergyIntegral {
    name = "battery/house/discharge_total_energy";
    icon = "mdi:battery-minus";
    source = batteryDischargingPower.name;
  };

  # Mirrors must propagate the source's availability too, not just its
  # state — `states(x) | float(0)` silently turns "unavailable" into 0,
  # which would publish a false reset one hop downstream.
  mkAggregate = { name, icon, source }: {
    inherit name icon;
    unique_id = ha.genId name;
    state = "{{ states('${source}') | float(0) }}";
    availability = "{{ states('${source}') not in ['unknown', 'unavailable', 'none'] }}";
    unit_of_measurement = "kWh";
    device_class = "energy";
    state_class = "total_increasing";
  };

  aggregates = [
    (mkAggregate {
      name = "battery/charge_total_energy";
      icon = "mdi:battery-plus";
      source = "sensor.${ha.genId batteryHouseChargeTotal.name}";
    })
    (mkAggregate {
      name = "battery/discharge_total_energy";
      icon = "mdi:battery-minus";
      source = "sensor.${ha.genId batteryHouseDischargeTotal.name}";
    })
  ];

  mkUtilityMeters = { base, source }:
    builtins.listToAttrs (map (cycle: {
      name = "${base}_${cycle}";
      value = { inherit source cycle; };
    }) [ "hourly" "daily" "monthly" ]);

  batteryUtilityMeters =
    (mkUtilityMeters {
      base = ha.genId batteryHouseChargeTotal.name;
      source = "sensor.${ha.genId batteryHouseChargeTotal.name}";
    })
    // (mkUtilityMeters {
      base = ha.genId batteryHouseDischargeTotal.name;
      source = "sensor.${ha.genId batteryHouseDischargeTotal.name}";
    });
in
{

  services.home-assistant.config = {


    powercalc = {
      sensors = [ ];
    };

    template = [
      {
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.battery_percentage_change";
          }
        ];
        binary_sensor = [
          {
            name = "solar/battery/is_charging";
            unique_id = "solar_battery_is_charging";
            device_class = "battery_charging";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% if battery_change > 0 %}
                on
              {% else %}
                off
              {% endif %}
            '';
          }
          {
            name = "solar/battery/is_grid_charging";
            unique_id = "solar_battery_is_grid_charging";
            device_class = "battery_charging";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% set grid_power = states('sensor.electricity_grid_consumed_power_mean_1m') | float(0) %}
              {% if battery_change > 0 and grid_power > 150 %}
                on
              {% else %}
                off
              {% endif %}
            '';
          }
        ];
      }
      {
        binary_sensor = [
          {
            name = "solar/battery/sufficient";
            unique_id = "solar_battery_sufficient";
            icon = "mdi:battery-high";
            state = ''
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(10) %}
              {{ battery > 10 }}
            '';
          }          
        ];
      }
      {
        sensor = [
          {
            name = "solar/battery/charging/remaining_minutes_till_overdischargesoc";
            unique_id = "solar_battery_charging_remaining_minutes_till_overdischargesoc";
            state = '' 
              {% set max_grid_power = states('number.system_house_pv_force_charge_power_limitation') | int(0) %}
              {% set battery_target = states('number.system_house_pv_overdischarge_soc') | int(0) %}
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
              {% set to_charge = battery_target - battery %}
              {% if to_charge > 0 %}
                {% set percent_in_wh = (48 + 35) %}
                {% set wh_needed = to_charge * percent_in_wh %}
                {% set charge_time = wh_needed / max_grid_power if max_grid_power > 0 else 'N/A' %}
                {{ (charge_time * 60) | round(0) }}
              {% else %}
                0
              {% endif %}
            '';
            state_class = "measurement";
          }
          {
            name = "solar/battery/overdischargesoc_target";
            unique_id = "solar_battery_overdischargesoc_target";
            unit_of_measurement = "%";
            device_class = "battery";
            state = ''
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {# Capaciteitstarief floor is 2.5 kW — never deep-discharge to shave below that. #}
              {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(2.5) %}
              {% set capacity_threshold = [2.5, monthly_peak - 0.1] | max %}
              {% set capacity_near = [2.2, monthly_peak - 0.3] | max %}
              {% set overdischargesoc = states('number.system_house_pv_overdischarge_soc') | int(20) %}
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(20) %}
              {% set is_car_charging = states('sensor.car_charger_power') | int(0) > 20 %}
              {% set is_solar_left = ((states('sensor.energy_production_today_remaining') | float(0) > 4) and now().hour >= 5) %}
              {% set overdischargesoc_default = 20 %}
              {% set overdischargesoc_charge_to = 15 %}
              {% set overdischargesoc_solar_left = 15 %}
              {# min is 10 #}
              {% set overdischargesoc_min = 8 %}
              {#
              Test values
              {% set power15m = 2.1 %}
              {% set power15m_estimated = 2.8 %}

              Echo's
              {{ power15m }}
              {{ power15m_estimated }}
              {{ overdischargesoc }}
              #}
              {# Capacity Tweaks #}
              {# Deep-discharge the battery to shave a peak only once it is imminent. Note the TWO
                 guards: it arms only if power15m > capacity_near AND power15m_estimated >
                 capacity_threshold. The car's charge control (system/car_charger/target_current)
                 keeps its projected 15-min average (power15m_estimated) below capacity_threshold —
                 the current steps snap down under the cap — so this second guard is never met while
                 the car is charging, and the battery never discharges to mask the car (which is what
                 drained it to 10% on 2026-07-03 ~04:00). This branch then fires only as a backstop
                 for real peaks the car alone cannot hold (and only in the billable band ≥ 2.5 kW).
                 See docs/ev-battery-peak-coordination.md. #}
              {% if (power15m > capacity_near) and (power15m_estimated > capacity_threshold) %}
                {{ overdischargesoc_min }}
              {# Night car charge: spread the battery over the night instead of letting self-use
                 dump it into the car in the first half hour (which leaves the grid peak budget
                 unused meanwhile). The floor steps down from the 22:00 SoC to 15% at 07:00, 1% at
                 a time; each step's ~83 Wh lets the car run a step higher under the same peak.
                 A floor above the current SoC holds the pack, it does not grid-charge it.
                 Simulated in docs/ev-battery-peak-coordination.md. #}
              {% elif (now().hour >= 22 or now().hour < 7) and is_state('binary_sensor.system_car_charger_should_charge', 'on') %}
                {% set start = states('sensor.solar_battery_soc_at_22h') | int(15) %}
                {% set elapsed = (now() - today_at('22:00')).total_seconds() % 86400 %}
                {% set fraction_left = [1 - elapsed / (9 * 3600), 0] | max %}
                {{ [15, (15 + (start - 15) * fraction_left) | round(0, 'ceil') | int] | max }}
              {# If solar left, prioritize to min even if car charging #}
              {% elif is_solar_left %}
                {{ overdischargesoc_solar_left }}
              {# If car charging and no solar left #}
              {% elif is_car_charging and is_solar_left == false %}
                {{ overdischargesoc_default }}
              {% else %}
                {% if battery < 12 %}
                  {{ overdischargesoc_charge_to }}
                {% else %}
                  {{ overdischargesoc_default }}
                {% endif %}
              {% endif %}
            '';
            state_class = "measurement";
          }
          {
            name = "solar/battery/forcechargesoc_target";
            unique_id = "solar_battery_forcechargesoc_target";
            unit_of_measurement = "%";
            device_class = "battery";
            state = ''
              {% set power15m = states('sensor.electricity_delivery_power_15m') | float(2) %}
              {% set power15m_estimated = states('sensor.electricity_delivery_power_15m_estimated') | float(2) %}
              {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(2.5) %}
              {% set capacity_threshold = [2.5, monthly_peak - 0.4] | max %}
              {% set capacity_safe = [2.0, monthly_peak - 1.0] | max %}
              {% set is_solar_left = ((states('sensor.energy_production_today_remaining') | float(0) > 3) and now().hour >= 5) %}
              {% set forcechargesoc = states('number.system_house_pv_force_charge_soc') | int(10) %}
              {% set is_offpeak = states('binary_sensor.electricity_is_offpeak') | bool(false) %}
              {% set forcechargesoc_high = 19 %}
              {% set forcechargesoc_low = 10 %}
              {% set forcechargesoc_min = 8 %}

              {% set forcechargesoc_target = forcechargesoc_min %}
              {{ forcechargesoc_target }}              
            '';
            state_class = "measurement";
          }
        ];
      }
      {
        trigger = [
          (ha.trigger.state "sensor.system_house_pv_battery_current_bms")
          (ha.trigger.state "sensor.system_house_pv_battery_voltage_bms")
          (ha.trigger.state "sensor.system_house_pv_battery_current_direction")
          (ha.trigger.time_pattern_minutes "/1")
        ];
        sensor = [ electricityBatteryPower ];
      }
      {
        # Battery SoC at the start of the night, for the overnight spread in
        # overdischargesoc_target. Trigger-based, so it survives an HA restart mid-night.
        trigger = [ (ha.trigger.at "22:00:00") ];
        sensor = [
          {
            name = "solar/battery/soc_at_22h";
            unique_id = "solar_battery_soc_at_22h";
            unit_of_measurement = "%";
            device_class = "battery";
            state = "{{ states('sensor.system_house_pv_battery_soc') | int(15) }}";
          }
        ];
      }
      {
        sensor = [ batteryChargingPower batteryDischargingPower ] ++ aggregates;
      }
    ];

    sensor = [ batteryHouseChargeTotal batteryHouseDischargeTotal ];

    utility_meter = batteryUtilityMeters;

    input_boolean = {
      solar_battery_charge_offpeak = {
        name = "solar/battery/charge_offpeak";
        icon = "mdi:battery";
      };
    };


    "automation manual" = [
      
      (ha.automation "solar/battery/charge" {
        triggers = [(ha.trigger.at "05:00:00")];
        conditions = [
          (ha.condition.on "input_boolean.solar_battery_charge_offpeak")
          (ha.condition.off "binary_sensor.electricity_high_usage")
        ];
        actions = [
          (ha.action.set_value "number.system_house_pv_force_charge_power_limitation" 1200)
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.system_house_pv_force_charge_soc" ''{{ states('number.system_house_pv_overdischarge_soc') | float(10) - 1 }}'')
          (ha.action.delay "00:00:30")
          (
            ha.action.conditional 
            [
              (ha.condition.template ''{{ states('sensor.energy_production_today_remaining') | int(0) > 8 }}'')
            ]
            [
              (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''20'')
            ]
            [
              (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''20'')
            ]
          )
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/max_charge" {
        triggers = [
          (ha.trigger.at "07:00:00")
        ];
        actions = [
          (ha.action.set_value "number.system_house_pv_force_charge_power_limitation" 300)     
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int(20) }}'')
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/overdischarge.control" {
        triggers = [(ha.trigger.state "sensor.solar_battery_overdischargesoc_target")];
        actions = [
          (ha.action.set_value "number.system_house_pv_overdischarge_soc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int }}'')
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/forcechargesoc.control" {
        triggers = [(ha.trigger.state_for "sensor.solar_battery_forcechargesoc_target" "00:00:15")];
        actions = [
          (ha.action.set_value "number.system_house_pv_force_charge_soc" ''{{ states('sensor.solar_battery_forcechargesoc_target') | int }}'')
        ];
        mode = "queued";
      })
    ];

  };
}
