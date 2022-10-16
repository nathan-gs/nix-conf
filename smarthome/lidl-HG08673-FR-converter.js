const fz = require('zigbee-herdsman-converters/converters/fromZigbee');
const tz = require('zigbee-herdsman-converters/converters/toZigbee');
const exposes = require('zigbee-herdsman-converters/lib/exposes');
const reporting = require('zigbee-herdsman-converters/lib/reporting');
const extend = require('zigbee-herdsman-converters/lib/extend');
const ota = require('zigbee-herdsman-converters/lib/ota');
const tuya = require('zigbee-herdsman-converters/lib/tuya');
const utils = require('zigbee-herdsman-converters/lib/utils');
const e = exposes.presets;
const ea = exposes.access;

const definition = {
    fingerprint: [{modelID: 'TS011F', manufacturerName: '_TZ3000_ynmowqk2'}, {modelID: 'TS011F', manufacturerName: '_TZ3000_r6buo8ba'}],
    model: 'HG08673-FR',
    vendor: 'Lidl',
    description: 'Silvercrest smart plug FR with power monitoring',
    fromZigbee: [tuya.fzDataPoints],
    toZigbee: [tuya.tzDataPoints],
    exposes: [e.energy()],
    configure: tuya.configureMagicPacket,
    meta: {
        tuyaDatapoints: [
            [17, 'energy', tuya.valueConverter.divideBy100],
        ],
    },
};

module.exports = definition;