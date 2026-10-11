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
              {# Deepest peak-shave floor. The inverter overshoots its floor by ~1 point, so 10 keeps
                 the reading at 9 or above, clear of the 8% hard limit (force charge trips at 9). #}
              {% set overdischargesoc_min = 10 %}
              {# Capacity Tweaks #}
              {# The battery DOES shave peaks, but never on behalf of the car: the car is throttled
                 instead (system/car_charger/target_current), because the pack cannot keep up with it
                 — on 2026-10-10 ~22:00 the car drained it 14% -> 7% in 12 minutes through this
                 branch, and on 2026-07-03 to 10%. So it arms only while the car is NOT charging, and
                 only on a real, billable (>= 2.5 kW) projected peak. The floor is
                 overdischargesoc_min (10%), with forcechargesoc_target as the grid-charge safety net
                 so the pack never reads below 8%. See docs/ev-battery-peak-coordination.md. #}
              {% if not is_car_charging and (power15m > capacity_near) and (power15m_estimated > capacity_threshold) %}
                {{ overdischargesoc_min }}
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
              {# Hard floor: the house battery must never read below 8%. The inverter overshoots its
                 floor by ~1 point and idle load drifts it a further point on a long night (2026-10-10:
                 8% floor -> 7% -> 6% with this at 7), so trip the grid force-charge at 9. #}
              {% set forcechargesoc_min = 9 %}

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
