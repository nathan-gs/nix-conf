{ config, lib, pkgs, ha, ... }:
let

  # addr 2 = master US5000, addr 3 = expansion US3000C (see docs/solis-modbus.md
  # "Direct Pylontech vs Solis?"). Read-only diagnostics — sensor.system_house_pv_battery_soc
  # (Solis/CAN) stays the automation input, these feed a maintenance dashboard only.
  packs = [
    { addr = 2; label = "US5000"; }
    { addr = 3; label = "US3000C"; }
  ];

  # LFP voltage only fans out on the upper knee (~90–100 % SoC). 40 mV at
  # rest there is "needs a longer absorb", not a failing cell — today's
  # 147 mV collapsed to 1 mV once the pack dropped onto the plateau.
  # Page only when the spread is still there *off* the knee (weak cell at
  # the bottom) or a cell is emptying while SoC still says otherwise.
  cellImbalanceAlertMv = 40;
  cellImbalancePlateauSoc = 90;
  cellImbalanceFor = "00:15:00";
  cellLowVoltageV = 3.05;
  cellLowVoltageMinSoc = 15;
  cellLowVoltageFor = "00:15:00";
  maxTempAlertC = 45;
  maxTempFor = "00:10:00";

  # Pylontech's own guidance is a full absorb ~monthly for SoC calibration
  # and balancing. 45 d is the outer edge of that (a bit past 30 d) and is
  # OK here: 147 mV at the 90–100 % knee is not capacity loss, the plateau
  # / cell-low alerts catch a real weak cell, and summer still clips 98 %+
  # on big PV days. Seeded to 2026-08-12 — last known full
  # (pylontech2mqtt only started recording 2026-08-21).
  lastRebalanceInitial = "2026-08-12 12:00:00";
  rebalanceMaxDaysDefault = 45;
  # Continuous hours at Solis SoC ≥ 98 % that count as an absorb window.
  # Touching 99 % for ~2 h (2026-08-26) was not enough for cell 12.
  # Manual grid fill: docs/battery-grid-charge-to-100.md.
  rebalanceAbsorbHours = 4;
  # Cells actually together *on* the knee: the gold-standard stamp.
  rebalanceCellsImbalanceMv = 30;
  rebalanceCellsMinV = 3.45;
  rebalanceCellsFor = "00:20:00";

  lastRebalanceEntity = "input_datetime.solar_battery_last_rebalance";
  rebalanceMaxDaysEntity = "input_number.solar_battery_rebalance_max_days";
  daysSinceEntity = "sensor.solar_battery_days_since_rebalance";
  overdueEntity = "binary_sensor.solar_battery_rebalance_overdue";
  solisSocEntity = "sensor.system_house_pv_battery_soc";

  rebalanceActiveEntity = "input_boolean.solar_battery_rebalance_active";
  rebalanceAbsorbTimingEntity = "input_boolean.solar_battery_rebalance_absorb_timing";
  rebalanceRunStartEntity = "input_datetime.solar_battery_rebalance_run_start";
  rebalanceAbsorbStartEntity = "input_datetime.solar_battery_rebalance_absorb_start";
  rebalanceSnapshotEntity = "input_text.solar_battery_rebalance_snapshot";
  rebalanceUsingGridEntity = "input_boolean.solar_battery_rebalance_using_grid";
  rebalanceSolarEnoughEntity = "binary_sensor.solar_battery_rebalance_solar_enough";
  # TOU charge current is *battery* amps at ~50 V, not AC. 20 A ≈ 1.0 kW
  # grid, well under the 2.5 kW capaciteitstarief floor. Tick still
  # peak-caps so house load + this charge cannot stack over that floor.
  rebalanceChargeCurrentA = 20;
  rebalancePeakMarginKw = 0.2;
  rebalanceChargeCurrentTargetEntity = "sensor.solar_battery_rebalance_charge_current_target";
  rebalanceTimeoutHours = 16;
  # US5000 4.8 kWh + US3000C 3.5 kWh (same 83 Wh/% as battery.nix).
  rebalancePackKwh = 8.3;
  rebalanceSolarMarginKwh = 1.5;
  solisWriteDelay = "00:00:15";

  storageModeEntity = "select.system_house_pv_storage_mode";
  allowGridEntity = "switch.system_house_pv_allow_grid_to_charge_the_battery";
  touChargeCurrentEntity = "number.system_house_pv_time_charging_charge_current";
  touDischargeCurrentEntity = "number.system_house_pv_time_charging_discharge_current";
  touChargeStartEntity = "time.system_house_pv_time_charging_charge_start_slot_1";
  touChargeEndEntity = "time.system_house_pv_time_charging_charge_end_slot_1";
  touDischargeStartEntity = "time.system_house_pv_time_charging_discharge_start_slot_1";
  touDischargeEndEntity = "time.system_house_pv_time_charging_discharge_end_slot_1";
  carChargerSwitch = "switch.system_car_charger";

  # Poll cycle is 5 min; go unavailable well past that (not on one missed
  # cycle) if pylontech2mqtt stops running, rather than silently freezing
  # on the last retained value forever.
  expireAfterSec = 1200;

  # MQTT discovery slugs the *name* ("State of Charge" → state_of_charge),
  # not the unique_id suffix ("soc"). Pass the live HA object_id here.
  entityId = pack: id: "sensor.pylontech_${lib.toLower pack.label}_pack_${toString pack.addr}_${id}";

  packAvailable = pack: ''
    states('${entityId pack "cell_imbalance"}') not in ['unknown', 'unavailable']
    and states('${entityId pack "state_of_charge"}') not in ['unknown', 'unavailable']
  '';

  plateauImbalanceTemplate = pack: ''
    {% set imb = states('${entityId pack "cell_imbalance"}') %}
    {% set soc = states('${entityId pack "state_of_charge"}') %}
    {{ ${packAvailable pack}
       and (soc | float(100)) < ${toString cellImbalancePlateauSoc}
       and (imb | float(0)) > ${toString cellImbalanceAlertMv} }}
  '';

  cellLowTemplate = pack: ''
    {% set vmin = states('${entityId pack "cell_min_voltage"}') %}
    {% set soc = states('${entityId pack "state_of_charge"}') %}
    {{ ${packAvailable pack}
       and states('${entityId pack "cell_min_voltage"}') not in ['unknown', 'unavailable']
       and (soc | float(0)) > ${toString cellLowVoltageMinSoc}
       and (vmin | float(4)) < ${toString cellLowVoltageV} }}
  '';

  cellsBalancedTemplate = ''
    {% set soc = states('${solisSocEntity}') | float(0) %}
    {% set imb2 = states('${entityId (builtins.elemAt packs 0) "cell_imbalance"}') %}
    {% set imb3 = states('${entityId (builtins.elemAt packs 1) "cell_imbalance"}') %}
    {% set vmin2 = states('${entityId (builtins.elemAt packs 0) "cell_min_voltage"}') %}
    {% set vmin3 = states('${entityId (builtins.elemAt packs 1) "cell_min_voltage"}') %}
    {{ soc >= 98
       and imb2 not in ['unknown', 'unavailable']
       and imb3 not in ['unknown', 'unavailable']
       and vmin2 not in ['unknown', 'unavailable']
       and vmin3 not in ['unknown', 'unavailable']
       and (imb2 | float(99)) < ${toString rebalanceCellsImbalanceMv}
       and (imb3 | float(99)) < ${toString rebalanceCellsImbalanceMv}
       and (vmin2 | float(0)) > ${toString rebalanceCellsMinV}
       and (vmin3 | float(0)) > ${toString rebalanceCellsMinV} }}
  '';

  lastRebalanceAsLocal = ''(states('${lastRebalanceEntity}') | as_datetime | as_local)'';

  packSlug = pack: "${lib.toLower pack.label}_pack_${toString pack.addr}";

  templateTrigger = id: template: for: {
    platform = "template";
    id = id;
    value_template = template;
    for = for;
  };

  packTemplateTrigger = pack: template: for:
    templateTrigger (packSlug pack) template for;

  packSensors = pack: let
    topic = "pylontech/pack_${toString pack.addr}/state";
    device = {
      identifiers = [ "pylontech_pack_${toString pack.addr}" ];
      name = "Pylontech ${pack.label} (pack ${toString pack.addr})";
      manufacturer = "Pylontech";
      model = pack.label;
    };
    entity = id: label: field: extra: {
      name = label;
      unique_id = ha.genId "pylontech_pack_${toString pack.addr}_${id}";
      state_topic = topic;
      value_template = "{{ value_json.${field} }}";
      entity_category = "diagnostic";
      state_class = "measurement";
      expire_after = expireAfterSec;
      device = device;
    } // extra;
  in [
    (entity "voltage" "Voltage" "voltage" { unit_of_measurement = "V"; device_class = "voltage"; })
    (entity "current" "Current" "current" { unit_of_measurement = "A"; device_class = "current"; })
    (entity "soc" "State of Charge" "soc_pct" { unit_of_measurement = "%"; device_class = "battery"; })
    (entity "remaining_capacity" "Remaining Capacity" "remaining_ah" { unit_of_measurement = "Ah"; })
    (entity "total_capacity" "Total Capacity" "total_ah" { unit_of_measurement = "Ah"; })
    (entity "cycles" "Cycles" "cycle" { state_class = "total_increasing"; })
    (entity "cell_min_voltage" "Cell Min Voltage" "cell_min_v" { unit_of_measurement = "V"; device_class = "voltage"; })
    (entity "cell_max_voltage" "Cell Max Voltage" "cell_max_v" { unit_of_measurement = "V"; device_class = "voltage"; })
    (entity "cell_imbalance" "Cell Imbalance" "cell_imbalance_mv" {
      unit_of_measurement = "mV";
      json_attributes_topic = topic;
      json_attributes_template = "{{ {'cell_voltages': value_json.cell_voltages} | tojson }}";
    })
    (entity "avg_temperature" "Avg Temperature" "avg_temp" { unit_of_measurement = "°C"; device_class = "temperature"; })
    (entity "min_temperature" "Min Temperature" "min_temp" { unit_of_measurement = "°C"; device_class = "temperature"; })
    (entity "max_temperature" "Max Temperature" "max_temp" { unit_of_measurement = "°C"; device_class = "temperature"; })
  ];

  systemAlarmTopic = "pylontech/system/alarm";
  systemAlarmEntityId = "binary_sensor.pylontech_system_alarm";

  stampLastRebalance = {
    service = "input_datetime.set_datetime";
    target.entity_id = lastRebalanceEntity;
    data.datetime = "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}";
  };

  stampDatetime = entity: {
    service = "input_datetime.set_datetime";
    target.entity_id = entity;
    data.datetime = "{{ now().strftime('%Y-%m-%d %H:%M:%S') }}";
  };

  setTime = entity: time: {
    service = "time.set_value";
    target.entity_id = entity;
    data.time = time;
  };

  snapshotJson = ''
    {{ {
      "m": states('${storageModeEntity}'),
      "g": states('${allowGridEntity}'),
      "ca": states('${touChargeCurrentEntity}'),
      "da": states('${touDischargeCurrentEntity}'),
      "cs": states('${touChargeStartEntity}'),
      "ce": states('${touChargeEndEntity}'),
      "ds": states('${touDischargeStartEntity}'),
      "de": states('${touDischargeEndEntity}')
    } | to_json }}
  '';

  # Expression (no {{ }}) — snapshot is always written before restore.
  snap = field: default: "(states('${rebalanceSnapshotEntity}') | from_json).${field} | default('${default}')";

  asLocal = entity: ''(states('${entity}') | as_datetime | as_local)'';

  absorbElapsedOk = ''
    {% set start = ${asLocal rebalanceAbsorbStartEntity} %}
    {{ is_state('${rebalanceAbsorbTimingEntity}', 'on')
       and start is not none
       and (now() - start).total_seconds() >= ${toString (rebalanceAbsorbHours * 3600)}
       and states('${solisSocEntity}') | float(0) >= 98 }}
  '';

  runTimedOut = ''
    {% set start = ${asLocal rebalanceRunStartEntity} %}
    {{ start is not none
       and (now() - start).total_seconds() >= ${toString (rebalanceTimeoutHours * 3600)} }}
  '';

  restoreAllowGrid = ha.action.conditional
    [ (ha.condition.template "{{ ${snap "g" "off"} == 'on' }}") ]
    [ (ha.action.on allowGridEntity) ]
    [ (ha.action.off allowGridEntity) ];

  armGridActions = [
    (ha.action.on rebalanceUsingGridEntity)
    (ha.action.on allowGridEntity)
    (ha.action.delay solisWriteDelay)
    (ha.action.set_value storageModeEntity "Self-Use + TOU")
    (ha.action.delay solisWriteDelay)
    (ha.action.set_value touDischargeCurrentEntity 0)
    (ha.action.delay solisWriteDelay)
    (setTime touDischargeStartEntity "00:00:00")
    (ha.action.delay solisWriteDelay)
    (setTime touDischargeEndEntity "00:00:00")
    (ha.action.delay solisWriteDelay)
    (setTime touChargeStartEntity "{{ now().strftime('%H:%M:00') }}")
    (ha.action.delay solisWriteDelay)
    (setTime touChargeEndEntity "23:59:00")
    (ha.action.delay solisWriteDelay)
    (ha.action.set_value touChargeCurrentEntity "{{ states('${rebalanceChargeCurrentTargetEntity}') | int(${toString rebalanceChargeCurrentA}) }}")
  ];

  restoreSolisActions = [
    (ha.action.set_value touChargeCurrentEntity 0)
    (ha.action.delay solisWriteDelay)
    (setTime touChargeStartEntity "{{ ${snap "cs" "00:00:00"} }}")
    (ha.action.delay solisWriteDelay)
    (setTime touChargeEndEntity "{{ ${snap "ce" "00:00:00"} }}")
    (ha.action.delay solisWriteDelay)
    (setTime touDischargeStartEntity "{{ ${snap "ds" "00:00:00"} }}")
    (ha.action.delay solisWriteDelay)
    (setTime touDischargeEndEntity "{{ ${snap "de" "00:00:00"} }}")
    (ha.action.delay solisWriteDelay)
    (ha.action.set_value touDischargeCurrentEntity "{{ ${snap "da" "0"} }}")
    (ha.action.delay solisWriteDelay)
    (ha.action.set_value storageModeEntity "{{ ${snap "m" "Self-Use"} }}")
    (ha.action.delay solisWriteDelay)
    restoreAllowGrid
    (ha.action.delay solisWriteDelay)
    (ha.action.set_value touChargeCurrentEntity "{{ ${snap "ca" "0"} }}")
    (ha.action.delay solisWriteDelay)
  ];

  restoreActions = message: [
    (ha.action.conditional
      [ (ha.condition.on rebalanceUsingGridEntity) ]
      restoreSolisActions
      [ ]
    )
    (ha.action.off rebalanceAbsorbTimingEntity)
    (ha.action.off rebalanceUsingGridEntity)
    (ha.action.off rebalanceActiveEntity)
    (ha.action.notify "Battery rebalance" message)
  ];

in
{
  services.home-assistant.config = {
    mqtt.sensor = lib.concatMap packSensors packs;

    mqtt.binary_sensor = [
      {
        name = "Alarm";
        unique_id = ha.genId "pylontech_system_alarm";
        state_topic = systemAlarmTopic;
        value_template = "{{ 'ON' if value_json.problem else 'OFF' }}";
        payload_on = "ON";
        payload_off = "OFF";
        device_class = "problem";
        entity_category = "diagnostic";
        expire_after = expireAfterSec;
        json_attributes_topic = systemAlarmTopic;
        json_attributes_template = "{{ value_json | tojson }}";
        device = {
          identifiers = [ "pylontech_system" ];
          name = "Pylontech System";
          manufacturer = "Pylontech";
        };
      }
    ];

    input_datetime = {
      solar_battery_last_rebalance = {
        name = "solar/battery/last_rebalance";
        has_date = true;
        has_time = true;
        initial = lastRebalanceInitial;
        icon = "mdi:battery-sync";
      };
      solar_battery_rebalance_run_start = {
        name = "solar/battery/rebalance_run_start";
        has_date = true;
        has_time = true;
        icon = "mdi:timer-play";
      };
      solar_battery_rebalance_absorb_start = {
        name = "solar/battery/rebalance_absorb_start";
        has_date = true;
        has_time = true;
        icon = "mdi:timer-check";
      };
    };

    input_boolean = {
      solar_battery_rebalance_active = {
        name = "solar/battery/rebalance_active";
        icon = "mdi:battery-sync";
      };
      solar_battery_rebalance_absorb_timing = {
        name = "solar/battery/rebalance_absorb_timing";
        icon = "mdi:timer-outline";
      };
      solar_battery_rebalance_using_grid = {
        name = "solar/battery/rebalance_using_grid";
        icon = "mdi:transmission-tower";
      };
    };

    input_text = {
      solar_battery_rebalance_snapshot = {
        name = "solar/battery/rebalance_snapshot";
        max = 255;
        icon = "mdi:content-save";
      };
    };

    input_number = {
      solar_battery_rebalance_max_days = {
        name = "solar/battery/rebalance_max_days";
        min = 14;
        max = 90;
        step = 1;
        initial = rebalanceMaxDaysDefault;
        mode = "box";
        unit_of_measurement = "d";
        icon = "mdi:calendar-clock";
      };
    };

    template = [
      {
        sensor = [
          {
            name = "solar/battery/days_since_rebalance";
            unique_id = ha.genId "solar/battery/days_since_rebalance";
            unit_of_measurement = "d";
            icon = "mdi:calendar-clock";
            state_class = "measurement";
            state = ''
              {% set last = ${lastRebalanceAsLocal} %}
              {% if last %}
                {{ ((now() - last).total_seconds() / 86400) | int }}
              {% endif %}
            '';
            availability = "{{ ${lastRebalanceAsLocal} is not none }}";
          }
          {
            name = "solar/battery/rebalance_absorb_remaining";
            unique_id = ha.genId "solar/battery/rebalance_absorb_remaining";
            unit_of_measurement = "min";
            icon = "mdi:timer-sand";
            state_class = "measurement";
            state = ''
              {% if not is_state('${rebalanceActiveEntity}', 'on') %}
                0
              {% elif not is_state('${rebalanceAbsorbTimingEntity}', 'on') %}
                ${toString (rebalanceAbsorbHours * 60)}
              {% else %}
                {% set start = ${asLocal rebalanceAbsorbStartEntity} %}
                {% set left = ${toString (rebalanceAbsorbHours * 3600)} - (now() - start).total_seconds() %}
                {{ [0, (left / 60) | round(0)] | max | int }}
              {% endif %}
            '';
          }
          {
            name = "solar/battery/rebalance_charge_current_target";
            unique_id = ha.genId "solar/battery/rebalance_charge_current_target";
            unit_of_measurement = "A";
            device_class = "current";
            state_class = "measurement";
            icon = "mdi:current-dc";
            state = ''
              {# Battery-side amps. 20 A × ~50 V ≈ 1 kW, not 20 A × 230 V. #}
              {% set cap = [2.5, states('sensor.electricity_delivery_power_monthly_15m_max') | float(0)] | max %}
              {% set import_w = states('sensor.electricity_grid_consumed_power_mean_1m') | float(states('sensor.electricity_grid_consumed_power') | float(0)) %}
              {% set batt_w = states('sensor.electricity_battery_power') | float(0) %}
              {% set batt_charge_kw = [0, -batt_w / 1000] | max %}
              {% set other_kw = (import_w / 1000) - batt_charge_kw %}
              {% set pack_v = states('sensor.system_house_pv_battery_voltage_bms') | float(50) %}
              {% set pack_v = pack_v if pack_v >= 40 else 50 %}
              {% set headroom_kw = cap - ${toString rebalancePeakMarginKw} - other_kw %}
              {% set amps = (headroom_kw * 1000 / pack_v) | round(0) | int %}
              {{ [[amps, 0] | max, ${toString rebalanceChargeCurrentA}] | min }}
            '';
          }
        ];
        binary_sensor = [
          {
            name = "solar/battery/rebalance_solar_enough";
            unique_id = ha.genId "solar/battery/rebalance_solar_enough";
            icon = "mdi:solar-power";
            state = ''
              {% set soc = states('${solisSocEntity}') | float(0) %}
              {% set to_full = (100 - soc) / 100 * ${toString rebalancePackKwh} %}
              {% set remaining = states('sensor.energy_production_today_remaining') | float(0) %}
              {{ soc >= 98 or remaining > (to_full + ${toString rebalanceSolarMarginKwh}) }}
            '';
          }
          {
            name = "solar/battery/rebalance_overdue";
            unique_id = ha.genId "solar/battery/rebalance_overdue";
            device_class = "problem";
            icon = "mdi:battery-alert";
            state = ''
              {% set days = states('${daysSinceEntity}') | float(0) %}
              {% set max_days = states('${rebalanceMaxDaysEntity}') | float(${toString rebalanceMaxDaysDefault}) %}
              {{ days >= max_days }}
            '';
            availability = "{{ states('${daysSinceEntity}') not in ['unknown', 'unavailable'] }}";
          }
        ];
      }
    ];

    "automation manual" = [
      (ha.automation "solar/battery/pylontech/alert.cell_imbalance" {
        triggers = map (pack: packTemplateTrigger pack (plateauImbalanceTemplate pack) cellImbalanceFor) packs;
        actions = [
          (ha.action.notify
            "Battery cell imbalance (off the knee)"
            ''{{ trigger.id }} is {{ states('sensor.pylontech_' + trigger.id + '_cell_imbalance') }} mV at {{ states('sensor.pylontech_' + trigger.id + '_state_of_charge') }}% SoC (threshold ${toString cellImbalanceAlertMv} mV below ${toString cellImbalancePlateauSoc}%). Min cell {{ states('sensor.pylontech_' + trigger.id + '_cell_min_voltage') }} V — spread on the plateau, not the normal 90–100% LFP knee. Check cell_voltages.''
          )
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/pylontech/alert.cell_low" {
        triggers = map (pack: packTemplateTrigger pack (cellLowTemplate pack) cellLowVoltageFor) packs;
        actions = [
          (ha.action.notify
            "Battery cell emptying early"
            ''{{ trigger.id }} min cell {{ states('sensor.pylontech_' + trigger.id + '_cell_min_voltage') }} V while pack SoC is still {{ states('sensor.pylontech_' + trigger.id + '_state_of_charge') }}% (alert below ${toString cellLowVoltageV} V above ${toString cellLowVoltageMinSoc}%). Weak cell is cutting usable capacity.''
          )
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/pylontech/alert.high_temperature" {
        triggers = map (pack: ha.trigger.above_for (entityId pack "max_temperature") maxTempAlertC maxTempFor) packs;
        actions = [
          (ha.action.notify
            "Battery pack overheating"
            ''{{ trigger.to_state.attributes.friendly_name }} is {{ trigger.to_state.state }} °C (threshold ${toString maxTempAlertC} °C).''
          )
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/pylontech/alert.system_alarm" {
        triggers = [ (ha.trigger.on systemAlarmEntityId) ];
        actions = [
          (ha.action.notify
            "Battery BMS alarm"
            ''Pylontech BMS reports: {{ trigger.to_state.attributes.active_alarms | join(', ') }}''
          )
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/pylontech/rebalance.record" {
        triggers = [
          ((ha.trigger.above_for solisSocEntity 97 "${lib.fixedWidthNumber 2 rebalanceAbsorbHours}:00:00") // { id = "absorb"; })
          (templateTrigger "cells" cellsBalancedTemplate rebalanceCellsFor)
        ];
        conditions = [
          (ha.condition.template ''
            {% set last = ${lastRebalanceAsLocal} %}
            {{ last is none or (now() - last).total_seconds() > 86400 }}
          '')
        ];
        actions = [
          stampLastRebalance
          (ha.action.notify
            "Battery rebalance recorded"
            ''{% if trigger.id == 'cells' %}Cells together on the knee (both packs < ${toString rebalanceCellsImbalanceMv} mV above ${toString rebalanceCellsMinV} V).{% else %}Solis SoC stayed ≥ 98% for ${toString rebalanceAbsorbHours} h.{% endif %} Next reminder in {{ states('${rebalanceMaxDaysEntity}') | int(${toString rebalanceMaxDaysDefault}) }} days.''
          )
        ];
        mode = "single";
      })
      (ha.automation "solar/battery/pylontech/rebalance.overdue" {
        triggers = [ (ha.trigger.at "18:00:00") ];
        conditions = [ (ha.condition.on overdueEntity) ];
        actions = [
          (ha.action.notify
            "Battery rebalance overdue"
            ''Last full absorb was {{ states('${daysSinceEntity}') }} days ago ({{ states('${lastRebalanceEntity}') }}). Trigger Rebalance pack: a sunny afternoon only blocks the car and waits for PV; if remaining solar cannot finish the pack (typical winter) it grid-charges at ~1 kW under the 2.5 kW peak cap.''
          )
        ];
        mode = "single";
      })
      (ha.automation "solar/battery/pylontech/rebalance.run" {
        triggers = [ ];
        actions = [
          (ha.action.conditional
            [ (ha.condition.on rebalanceActiveEntity) ]
            [
              (ha.action.notify
                "Battery rebalance"
                "Already running since {{ states('${rebalanceRunStartEntity}') }}. Trigger automation.solar_battery_pylontech_rebalance_cancel to abort and restore."
              )
            ]
            [
              (ha.action.set_value rebalanceSnapshotEntity snapshotJson)
              (stampDatetime rebalanceRunStartEntity)
              (ha.action.conditional
                [ (ha.condition.above solisSocEntity 97) ]
                [
                  (stampDatetime rebalanceAbsorbStartEntity)
                  (ha.action.on rebalanceAbsorbTimingEntity)
                ]
                [ (ha.action.off rebalanceAbsorbTimingEntity) ]
              )
              (ha.action.off rebalanceUsingGridEntity)
              (ha.action.on rebalanceActiveEntity)
              (ha.action.delay "00:00:05")
              (ha.action.off carChargerSwitch)
              (ha.action.conditional
                [ (ha.condition.on rebalanceSolarEnoughEntity) ]
                [
                  (ha.action.notify
                    "Battery rebalance started (solar)"
                    ''Enough PV left to finish the pack ({{ states('sensor.energy_production_today_remaining') | float(0) | round(1) }} kWh remaining). Car blocked; no grid charge. If the forecast fails, the watchdog switches to a ~1 kW grid fill. Cancel: automation.solar_battery_pylontech_rebalance_cancel.''
                  )
                ]
                (
                  armGridActions ++ [
                    (ha.action.notify
                      "Battery rebalance started (grid)"
                      ''Not enough PV left to finish the pack — grid TOU {{ states('${rebalanceChargeCurrentTargetEntity}') | int(${toString rebalanceChargeCurrentA}) }} A (max ${toString rebalanceChargeCurrentA} A ≈ 1 kW, peak-capped). Car blocked. Restores after ${toString rebalanceAbsorbHours} h at ≥ 98 %. Cancel: automation.solar_battery_pylontech_rebalance_cancel.''
                    )
                  ]
                )
              )
            ]
          )
        ];
        mode = "single";
      })
      (ha.automation "solar/battery/pylontech/rebalance.cancel" {
        triggers = [ ];
        conditions = [ (ha.condition.on rebalanceActiveEntity) ];
        actions = restoreActions "Cancelled — Solis setpoints restored, car charging unblocked.";
        mode = "single";
      })
      (ha.automation "solar/battery/pylontech/rebalance.tick" {
        triggers = [
          (ha.trigger.time_pattern_minutes "/5")
          {
            platform = "homeassistant";
            event = "start";
          }
        ];
        conditions = [ (ha.condition.on rebalanceActiveEntity) ];
        actions = [
          (ha.action.conditional
            [ (ha.condition.on rebalanceUsingGridEntity)
              (ha.condition.template ''
                {% set t = states('${rebalanceChargeCurrentTargetEntity}') | int(-1) %}
                {% set c = states('${touChargeCurrentEntity}') | float(-1) | round(0) | int %}
                {{ t >= 0 and t != c }}
              '') ]
            [ (ha.action.set_value touChargeCurrentEntity "{{ states('${rebalanceChargeCurrentTargetEntity}') | int(0) }}") ]
            [ ]
          )
          {
            choose = [
              {
                conditions = [ (ha.condition.template runTimedOut) ];
                sequence = restoreActions "Timed out after ${toString rebalanceTimeoutHours} h without ${toString rebalanceAbsorbHours} h at ≥ 98 %. Solis setpoints restored.";
              }
              {
                conditions = [ (ha.condition.template absorbElapsedOk) ];
                sequence = [
                  stampLastRebalance
                ] ++ restoreActions "Absorb complete (${toString rebalanceAbsorbHours} h at ≥ 98 %). Solis setpoints restored, car charging unblocked.";
              }
              {
                conditions = [
                  (ha.condition.off rebalanceUsingGridEntity)
                  (ha.condition.off rebalanceSolarEnoughEntity)
                  (ha.condition.below solisSocEntity 98)
                ];
                sequence = armGridActions ++ [
                  (ha.action.notify
                    "Battery rebalance → grid"
                    ''Remaining PV cannot finish the pack — switching to grid TOU {{ states('${rebalanceChargeCurrentTargetEntity}') | int(${toString rebalanceChargeCurrentA}) }} A (peak-capped under 2.5 kW).''
                  )
                ];
              }
              {
                conditions = [
                  (ha.condition.above solisSocEntity 97)
                  (ha.condition.off rebalanceAbsorbTimingEntity)
                ];
                sequence = [
                  (stampDatetime rebalanceAbsorbStartEntity)
                  (ha.action.on rebalanceAbsorbTimingEntity)
                ];
              }
              {
                conditions = [
                  (ha.condition.below solisSocEntity 98)
                  (ha.condition.on rebalanceAbsorbTimingEntity)
                ];
                sequence = [ (ha.action.off rebalanceAbsorbTimingEntity) ];
              }
            ];
            default = [
              (ha.action.conditional
                [ (ha.condition.on rebalanceUsingGridEntity)
                  (ha.condition.template ''
                    {% set start = states('${touChargeStartEntity}') %}
                    {% set end = states('${touChargeEndEntity}') %}
                    {% set now_t = now().strftime('%H:%M:%S') %}
                    {{ start in ['unknown', 'unavailable']
                       or end in ['unknown', 'unavailable']
                       or now_t < start or now_t > end }}
                  '') ]
                [
                  (setTime touChargeStartEntity "{{ now().strftime('%H:%M:00') }}")
                  (ha.action.delay solisWriteDelay)
                  (setTime touChargeEndEntity "23:59:00")
                ]
                [ ]
              )
            ];
          }
        ];
        mode = "single";
        max_exceeded = "silent";
      })
    ];
  };
}
