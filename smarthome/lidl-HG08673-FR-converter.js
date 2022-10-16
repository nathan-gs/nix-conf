const fz = require('zigbee-herdsman-converters/converters/fromZigbee');
const tz = require('zigbee-herdsman-converters/converters/toZigbee');
const exposes = require('zigbee-herdsman-converters/lib/exposes');
const reporting = require('zigbee-herdsman-converters/lib/reporting');
const ota = require('zigbee-herdsman-converters/lib/ota');
const utils = require('zigbee-herdsman-converters/lib/utils');

const e = exposes.presets;
const ea = exposes.access;

const fzLocal = {
  metering_skip_duplicate: {
      ...fz.metering,
      convert: (model, msg, publish, options, meta) => {
          if (utils.hasAlreadyProcessedMessage(msg)) return;
          return fz.metering.convert(model, msg, publish, options, meta);
      },
  },
  electrical_measurement_skip_duplicate: {
      ...fz.electrical_measurement,
      convert: (model, msg, publish, options, meta) => {
          if (utils.hasAlreadyProcessedMessage(msg)) return;
          return fz.electrical_measurement.convert(model, msg, publish, options, meta);
      },
  },
};

const definition = {
  fingerprint: [{modelID: 'TS011F', manufacturerName: '_TZ3000_ynmowqk2'}],
  model: 'HG08673-FR',
  vendor: 'Lidl',
  description: 'Silvercrest smart plug FR with power monitoring',
  ota: ota.zigbeeOTA,
  fromZigbee: [fz.on_off, fzLocal.electrical_measurement_skip_duplicate, fzLocal.metering_skip_duplicate, fz.ignore_basic_report,
    fz.tuya_switch_power_outage_memory, fz.ts011f_plug_indicator_mode, fz.ts011f_plug_child_mode],
  toZigbee: [tz.on_off, tz.tuya_switch_power_outage_memory, tz.ts011f_plug_indicator_mode, tz.ts011f_plug_child_mode],
  configure: async (device, coordinatorEndpoint, logger) => {
    const endpoint = device.getEndpoint(1);
    await endpoint.read('genBasic', ['manufacturerName', 'zclVersion', 'appVersion', 'modelId', 'powerSource', 0xfffe]);
    await reporting.bind(endpoint, coordinatorEndpoint, ['genOnOff', 'haElectricalMeasurement', 'seMetering']);
    await reporting.rmsVoltage(endpoint, {change: 5});
    await reporting.rmsCurrent(endpoint, {change: 50});
    await reporting.activePower(endpoint, {change: 10});
    await reporting.currentSummDelivered(endpoint);
    endpoint.saveClusterAttributeKeyValue('haElectricalMeasurement', {acCurrentDivisor: 1000, acCurrentMultiplier: 1});
    endpoint.saveClusterAttributeKeyValue('seMetering', {divisor: 100, multiplier: 1});
    device.save();
  },
  exposes: [e.switch(), e.power(), e.current(), e.voltage().withAccess(ea.STATE),
    e.energy(), exposes.enum('power_outage_memory', ea.ALL, ['on', 'off', 'restore'])
        .withDescription('Recover state after power outage'),
    exposes.enum('indicator_mode', ea.ALL, ['off', 'off/on', 'on/off', 'on'])
        .withDescription('Plug LED indicator mode'), e.child_lock()],
};



module.exports = definition;