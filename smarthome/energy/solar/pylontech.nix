{ config, lib, pkgs, ha, ... }:
let

  # addr 2 = master US5000, addr 3 = expansion US3000C (see docs/solis-modbus.md
  # "Direct Pylontech vs Solis?"). Read-only diagnostics — sensor.system_house_pv_battery_soc
  # (Solis/CAN) stays the automation input, these feed a maintenance dashboard only.
  packs = [
    { addr = 2; label = "US5000"; }
    { addr = 3; label = "US3000C"; }
  ];

  # Pylontech's own "needs balancing" threshold; basement never drops below 16 C
  # so only the high side of temperature is a real risk here (overheating, not
  # LFP charge-below-freezing damage).
  cellImbalanceAlertMv = 40;
  maxTempAlertC = 45;

  entityId = pack: id: "sensor.pylontech_${lib.toLower pack.label}_pack_${toString pack.addr}_${id}";

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
        json_attributes_topic = systemAlarmTopic;
        json_attributes_template = "{{ value_json | tojson }}";
        device = {
          identifiers = [ "pylontech_system" ];
          name = "Pylontech System";
          manufacturer = "Pylontech";
        };
      }
    ];

    "automation manual" = [
      (ha.automation "solar/battery/pylontech/alert.cell_imbalance" {
        triggers = map (pack: ha.trigger.above (entityId pack "cell_imbalance") cellImbalanceAlertMv) packs;
        actions = [
          (ha.action.notify
            "Battery cell imbalance"
            ''{{ trigger.to_state.attributes.friendly_name }} is {{ trigger.to_state.state }} mV (threshold ${toString cellImbalanceAlertMv} mV) — check cell_voltages attribute for the outlier cell.''
          )
        ];
        mode = "queued";
      })
      (ha.automation "solar/battery/pylontech/alert.high_temperature" {
        triggers = map (pack: ha.trigger.above (entityId pack "max_temperature") maxTempAlertC) packs;
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
    ];
  };
}
