{ config, lib, pkgs, ha, ... }:
let

  # addr 2 = master US5000, addr 3 = expansion US3000C (see docs/solis-modbus.md
  # "Direct Pylontech vs Solis?"). Read-only diagnostics — sensor.system_house_pv_battery_soc
  # (Solis/CAN) stays the automation input, these feed a maintenance dashboard only.
  packs = [
    { addr = 2; label = "US5000"; }
    { addr = 3; label = "US3000C"; }
  ];

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
    (entity "cell_imbalance" "Cell Imbalance" "cell_imbalance_mv" { unit_of_measurement = "mV"; })
    (entity "avg_temperature" "Avg Temperature" "avg_temp" { unit_of_measurement = "°C"; device_class = "temperature"; })
    (entity "min_temperature" "Min Temperature" "min_temp" { unit_of_measurement = "°C"; device_class = "temperature"; })
    (entity "max_temperature" "Max Temperature" "max_temp" { unit_of_measurement = "°C"; device_class = "temperature"; })
  ];

in
{
  services.home-assistant.config = {
    mqtt.sensor = lib.concatMap packSensors packs;
  };
}
