const exposes = require('zigbee-herdsman-converters/lib/exposes');
const fz = {...require('zigbee-herdsman-converters/converters/fromZigbee'), legacy: require('zigbee-herdsman-converters/lib/legacy').fromZigbee};
const tz = require('zigbee-herdsman-converters/converters/toZigbee');
const ota = require('zigbee-herdsman-converters/lib/ota');
const tuya = require('zigbee-herdsman-converters/lib/tuya');
const reporting = require('zigbee-herdsman-converters/lib/reporting');
const extend = require('zigbee-herdsman-converters/lib/extend');
const e = exposes.presets;
const ea = exposes.access;
const libColor = require('zigbee-herdsman-converters/lib/color');
const utils = require('zigbee-herdsman-converters/lib/utils');
const zosung = require('zigbee-herdsman-converters/lib/zosung');
const fzZosung = zosung.fzZosung;
const tzZosung = zosung.tzZosung;
const ez = zosung.presetsZosung;
const globalStore = require('zigbee-herdsman-converters/lib/store');

const TS011Fplugs = ['_TZ3000_5f43h46b', '_TZ3000_cphmq0q7', '_TZ3000_dpo1ysak', '_TZ3000_ew3ldmgx', '_TZ3000_gjnozsaz',
    '_TZ3000_jvzvulen', '_TZ3000_mraovvmm', '_TZ3000_nfnmi125', '_TZ3000_ps3dmato', '_TZ3000_w0qqde0g', '_TZ3000_u5u4cakc',
    '_TZ3000_rdtixbnu', '_TZ3000_typdpbpg', '_TZ3000_kx0pris5', '_TZ3000_amdymr7l', '_TZ3000_z1pnpsdo', '_TZ3000_ksw8qtmt',
    '_TZ3000_1h2x4akh', '_TZ3000_9vo5icau', '_TZ3000_cehuw1lw', '_TZ3000_ko6v90pg', '_TZ3000_f1bapcit', '_TZ3000_cjrngdr3',
    '_TZ3000_zloso4jk', '_TZ3000_r6buo8ba', '_TZ3000_iksasdbv', '_TZ3000_idrffznf', '_TZ3000_okaz9tjs', '_TZ3210_q7oryllx',
    '_TZ3000_ss98ec5d', '_TZ3000_gznh2xla', '_TZ3000_hdopuwv6', '_TZ3000_gvn91tmx', '_TZ3000_dksbtrzs', '_TZ3000_b28wrpvx',
    '_TZ3000_aim0ztek', '_TZ3000_mlswgkc3', '_TZ3000_7dndcnnb', '_TZ3000_waho4jtj', '_TZ3000_nmsciidq', '_TZ3000_jtgxgmks',
    '_TZ3000_rdfh8cfs', '_TZ3000_yujkchbz', '_TZ3000_fgwhjm9j', '_TZ3000_qeuvnohg'];

const tzLocal = {
    SA12IZL_silence_siren: {
        key: ['silence_siren'],
        convertSet: async (entity, key, value, meta) => {
            await tuya.sendDataPointBool(entity, 16, value);
        },
    },
    SA12IZL_alarm: {
        key: ['alarm'],
        convertSet: async (entity, key, value, meta) => {
            await tuya.sendDataPointEnum(entity, 20, {true: 0, false: 1}[value]);
        },
    },
    hpsz: {
        key: ['led_state'],
        convertSet: async (entity, key, value, meta) => {
            await tuya.sendDataPointBool(entity, tuya.dataPoints.HPSZLEDState, value);
        },
    },
    TS0504B_color: {
        key: ['color'],
        convertSet: async (entity, key, value, meta) => {
            const color = libColor.Color.fromConverterArg(value);
            console.log(color);
            const enableWhite =
                (color.isRGB() && (color.rgb.red === 1 && color.rgb.green === 1 && color.rgb.blue === 1)) ||
                // Zigbee2MQTT frontend white value
                (color.isXY() && (color.xy.x === 0.3125 || color.xy.y === 0.32894736842105265)) ||
                // Home Assistant white color picker value
                (color.isXY() && (color.xy.x === 0.323 || color.xy.y === 0.329));

            if (enableWhite) {
                await entity.command('lightingColorCtrl', 'tuyaRgbMode', {enable: false});
                const newState = {color_mode: 'xy'};
                if (color.isXY()) {
                    newState.color = color.xy;
                } else {
                    newState.color = color.rgb.gammaCorrected().toXY().rounded(4);
                }
                return {state: libColor.syncColorState(newState, meta.state, entity, meta.options, meta.logger)};
            } else {
                return await tz.light_color.convertSet(entity, key, value, meta);
            }
        },
    },
    power_on_behavior: {
        key: ['power_on_behavior'],
        convertSet: async (entity, key, value, meta) => {
            value = value.toLowerCase();
            const lookup = {'off': 0, 'on': 1, 'previous': 2};
            utils.validateValue(value, Object.keys(lookup));
            const pState = lookup[value];
            await entity.write('manuSpecificTuya_3', {'powerOnBehavior': pState}, {disableDefaultResponse: true});
            return {state: {power_on_behavior: value}};
        },
        convertGet: async (entity, key, meta) => {
            await entity.read('manuSpecificTuya_3', ['powerOnBehavior']);
        },
    },
    zb_sm_cover: {
        key: ['state', 'position', 'reverse_direction', 'top_limit', 'bottom_limit', 'favorite_position', 'goto_positon', 'report'],
        convertSet: async (entity, key, value, meta) => {
            switch (key) {
            case 'position': {
                const invert = (meta.state) ? !meta.state.invert_cover : false;
                value = invert ? 100 - value : value;
                if (value >= 0 && value <= 100) {
                    await tuya.sendDataPointValue(entity, tuya.dataPoints.coverPosition, value);
                } else {
                    throw new Error('TuYa_cover_control: Curtain motor position is out of range');
                }
                break;
            }
            case 'state': {
                const stateEnums = tuya.getCoverStateEnums(meta.device.manufacturerName);
                meta.logger.debug(`TuYa_cover_control: Using state enums for ${meta.device.manufacturerName}:
                ${JSON.stringify(stateEnums)}`);

                value = value.toLowerCase();
                switch (value) {
                case 'close':
                    await tuya.sendDataPointEnum(entity, tuya.dataPoints.state, stateEnums.close);
                    break;
                case 'open':
                    await tuya.sendDataPointEnum(entity, tuya.dataPoints.state, stateEnums.open);
                    break;
                case 'stop':
                    await tuya.sendDataPointEnum(entity, tuya.dataPoints.state, stateEnums.stop);
                    break;
                default:
                    throw new Error('TuYa_cover_control: Invalid command received');
                }
                break;
            }
            case 'reverse_direction': {
                meta.logger.info(`Motor direction ${(value) ? 'reverse' : 'forward'}`);
                await tuya.sendDataPointEnum(entity, tuya.dataPoints.motorDirection, (value) ? 1 : 0);
                break;
            }
            case 'top_limit': {
                await tuya.sendDataPointEnum(entity, 104, {'SET': 0, 'CLEAR': 1}[value]);
                break;
            }
            case 'bottom_limit': {
                await tuya.sendDataPointEnum(entity, 103, {'SET': 0, 'CLEAR': 1}[value]);
                break;
            }
            case 'favorite_position': {
                await tuya.sendDataPointValue(entity, 115, value);
                break;
            }
            case 'goto_positon': {
                if (value == 'FAVORITE') {
                    value = (meta.state) ? meta.state.favorite_position : null;
                } else {
                    value = parseInt(value);
                }
                return tz.tuya_cover_control.convertSet(entity, 'position', value, meta);
            }
            case 'report': {
                await tuya.sendDataPointBool(entity, 116, 0);
                break;
            }
            }
        },
    },
    x5h_thermostat: {
        key: ['system_mode', 'current_heating_setpoint', 'sensor', 'brightness_state', 'sound', 'frost_protection', 'week', 'factory_reset',
            'local_temperature_calibration', 'heating_temp_limit', 'deadzone_temperature', 'upper_temp', 'preset', 'child_lock',
            'schedule'],
        convertSet: async (entity, key, value, meta) => {
            switch (key) {
            case 'system_mode':
                await tuya.sendDataPointBool(entity, tuya.dataPoints.x5hState, value === 'heat');
                break;
            case 'preset': {
                value = value.toLowerCase();
                const lookup = {manual: 0, program: 1};
                utils.validateValue(value, Object.keys(lookup));
                value = lookup[value];
                await tuya.sendDataPointEnum(entity, tuya.dataPoints.x5hMode, value);
                break;
            }
            case 'upper_temp':
                if (value >= 35 && value <= 95) {
                    await tuya.sendDataPointValue(entity, tuya.dataPoints.x5hSetTempCeiling, value);
                    const setpoint = globalStore.getValue(entity, 'currentHeatingSetpoint', 20);
                    const setpointRaw = Math.round(setpoint * 10);
                    await new Promise((r) => setTimeout(r, 500));
                    await tuya.sendDataPointValue(entity, tuya.dataPoints.x5hSetTemp, setpointRaw);
                } else {
                    throw new Error('Supported values are in range [35, 95]');
                }
                break;
            case 'deadzone_temperature':
                if (value >= 0.5 && value <= 9.5) {
                    value = Math.round(value * 10);
                    await tuya.sendDataPointValue(entity, tuya.dataPoints.x5hTempDiff, value);
                } else {
                    throw new Error('Supported values are in range [0.5, 9.5]');
                }
                break;
            case 'heating_temp_limit':
                if (value >= 5 && value <= 60) {
                    await tuya.sendDataPointValue(entity, tuya.dataPoints.x5hProtectionTempLimit, value);
                } else {
                    throw new Error('Supported values are in range [5, 60]');
                }
                break;
            case 'local_temperature_calibration':
                if (value >= -9.9 && value <= 9.9) {
                    value = Math.round(value * 10);

                    if (value < 0) {
                        value = 0xFFFFFFFF + value + 1;
                    }

                    await tuya.sendDataPointValue(entity, tuya.dataPoints.x5hTempCorrection, value);
                } else {
                    throw new Error('Supported values are in range [-9.9, 9.9]');
                }
                break;
            case 'factory_reset':
                await tuya.sendDataPointBool(entity, tuya.dataPoints.x5hFactoryReset, value === 'ON');
                break;
            case 'week':
                await tuya.sendDataPointEnum(entity, tuya.dataPoints.x5hWorkingDaySetting,
                    utils.getKey(tuya.thermostatWeekFormat, value, value, Number));
                break;
            case 'frost_protection':
                await tuya.sendDataPointBool(entity, tuya.dataPoints.x5hFrostProtection, value === 'ON');
                break;
            case 'sound':
                await tuya.sendDataPointBool(entity, tuya.dataPoints.x5hSound, value === 'ON');
                break;
            case 'brightness_state': {
                value = value.toLowerCase();
                const lookup = {off: 0, low: 1, medium: 2, high: 3};
                utils.validateValue(value, Object.keys(lookup));
                value = lookup[value];
                await tuya.sendDataPointEnum(entity, tuya.dataPoints.x5hBackplaneBrightness, value);
                break;
            }
            case 'sensor': {
                value = value.toLowerCase();
                const lookup = {'internal': 0, 'external': 1, 'both': 2};
                utils.validateValue(value, Object.keys(lookup));
                value = lookup[value];
                await tuya.sendDataPointEnum(entity, tuya.dataPoints.x5hSensorSelection, value);
                break;
            }
            case 'current_heating_setpoint':
                if (value >= 5 && value <= 60) {
                    value = Math.round(value * 10);
                    await tuya.sendDataPointValue(entity, tuya.dataPoints.x5hSetTemp, value);
                } else {
                    throw new Error(`Unsupported value: ${value}`);
                }
                break;
            case 'child_lock':
                await tuya.sendDataPointBool(entity, tuya.dataPoints.x5hChildLock, value === 'LOCK');
                break;
            case 'schedule': {
                const periods = value.split(' ');
                const periodsNumber = 8;
                const payload = [];

                for (let i = 0; i < periodsNumber; i++) {
                    const timeTemp = periods[i].split('/');
                    const hm = timeTemp[0].split(':', 2);
                    const h = parseInt(hm[0]);
                    const m = parseInt(hm[1]);
                    const temp = parseFloat(timeTemp[1]);

                    if (h < 0 || h >= 24 || m < 0 || m >= 60 || temp < 5 || temp > 60) {
                        throw new Error('Invalid hour, minute or temperature of: ' + periods[i]);
                    }

                    const tempHexArray = tuya.convertDecimalValueTo2ByteHexArray(Math.round(temp * 10));
                    // 1 byte for hour, 1 byte for minutes, 2 bytes for temperature
                    payload.push(h, m, ...tempHexArray);
                }

                await tuya.sendDataPointRaw(entity, tuya.dataPoints.x5hWeeklyProcedure, payload);
                break;
            }
            default:
                break;
            }
        },
    },
    temperature_unit: {
        key: ['temperature_unit'],
        convertSet: async (entity, key, value, meta) => {
            switch (key) {
            case 'temperature_unit': {
                await entity.write('manuSpecificTuya_2', {'57355': {value: {'celsius': 0, 'fahrenheit': 1}[value], type: 48}});
                break;
            }
            default: // Unknown key
                meta.logger.warn(`Unhandled key ${key}`);
            }
        },
    },
};

const fzLocal = {
    SA12IZL: {
        cluster: 'manuSpecificTuya',
        type: ['commandDataResponse', 'commandDataReport'],
        convert: (model, msg, publish, options, meta) => {
            const result = {};
            for (const dpValue of msg.data.dpValues) {
                const dp = dpValue.dp;
                const value = tuya.getDataValue(dpValue);
                switch (dp) {
                case tuya.dataPoints.state:
                    result.smoke = value === 0;
                    break;
                case 15:
                    result.battery = value;
                    break;
                case 16:
                    result.silence_siren = value;
                    break;
                case 20: {
                    const alarm = {0: true, 1: false};
                    result.alarm = alarm[value];
                    break;
                }
                default:
                    meta.logger.warn(`zigbee-herdsman-converters:SA12IZL: NOT RECOGNIZED DP #${
                        dp} with data ${JSON.stringify(dpValue)}`);
                }
            }
            return result;
        },
    },
    tuya_dinrail_switch2: {
        cluster: 'manuSpecificTuya',
        type: ['commandDataReport', 'commandDataResponse', 'commandActiveStatusReport'],
        convert: (model, msg, publish, options, meta) => {
            const dpValue = tuya.firstDpValue(msg, meta, 'tuya_dinrail_switch2');
            const dp = dpValue.dp;
            const value = tuya.getDataValue(dpValue);
            const state = value ? 'ON' : 'OFF';

            switch (dp) {
            case tuya.dataPoints.state: // DPID that we added to common
                return {state: state};
            case tuya.dataPoints.dinrailPowerMeterTotalEnergy2:
                return {energy: value/100};
            case tuya.dataPoints.dinrailPowerMeterPower2:
                return {power: value};
            default:
                meta.logger.warn(`zigbee-herdsman-converters:TuyaDinRailSwitch: NOT RECOGNIZED DP ` +
                    `#${dp} with data ${JSON.stringify(dpValue)}`);
            }
        },
    },
    hpsz: {
        cluster: 'manuSpecificTuya',
        type: ['commandDataResponse', 'commandDataReport'],
        convert: (model, msg, publish, options, meta) => {
            const dpValue = tuya.firstDpValue(msg, meta, 'hpsz');
            const dp = dpValue.dp;
            const value = tuya.getDataValue(dpValue);
            let result = null;
            switch (dp) {
            case tuya.dataPoints.HPSZInductionState:
                result = {presence: value === 1};
                break;
            case tuya.dataPoints.HPSZPresenceTime:
                result = {duration_of_attendance: value};
                break;
            case tuya.dataPoints.HPSZLeavingTime:
                result = {duration_of_absence: value};
                break;
            case tuya.dataPoints.HPSZLEDState:
                result = {led_state: value};
                break;
            default:
                meta.logger.warn(`zigbee-herdsman-converters:hpsz: NOT RECOGNIZED DP #${
                    dp} with data ${JSON.stringify(dpValue)}`);
            }
            return result;
        },
    },
    metering_skip_duplicate: {
        ...fz.metering,
        convert: (model, msg, publish, options, meta) => {
            if (utils.hasAlreadyProcessedMessage(msg, model)) return;
            return fz.metering.convert(model, msg, publish, options, meta);
        },
    },
    electrical_measurement_skip_duplicate: {
        ...fz.electrical_measurement,
        convert: (model, msg, publish, options, meta) => {
            if (utils.hasAlreadyProcessedMessage(msg, model)) return;
            return fz.electrical_measurement.convert(model, msg, publish, options, meta);
        },
    },
    scenes_recall_scene_65029: {
        cluster: '65029',
        type: ['raw', 'attributeReport'],
        convert: (model, msg, publish, options, meta) => {
            const id = meta.device.modelID === '005f0c3b' ? msg.data[0] : msg.data[msg.data.length - 1];
            return {action: `scene_${id}`};
        },
    },
    TS0201_battery: {
        cluster: 'genPowerCfg',
        type: ['attributeReport', 'readResponse'],
        convert: (model, msg, publish, options, meta) => {
            // https://github.com/Koenkk/zigbee2mqtt/issues/11470
            if (msg.data.batteryPercentageRemaining == 200 && msg.data.batteryVoltage < 30) return;
            return fz.battery.convert(model, msg, publish, options, meta);
        },
    },
    TS0201_humidity: {
        ...fz.humidity,
        convert: (model, msg, publish, options, meta) => {
            const result = fz.humidity.convert(model, msg, publish, options, meta);
            if (meta.device.manufacturerName === '_TZ3000_ywagc4rj') {
                result.humidity = result.humidity * 10;
            }
            return result;
        },
    },
    TS0222: {
        cluster: 'manuSpecificTuya',
        type: ['commandDataResponse', 'commandDataReport'],
        convert: (model, msg, publish, options, meta) => {
            const result = {};
            for (const dpValue of msg.data.dpValues) {
                const dp = dpValue.dp;
                const value = tuya.getDataValue(dpValue);
                switch (dp) {
                case 2:
                    result.illuminance = value;
                    result.illuminance_lux = value;
                    break;
                case 4:
                    result.battery = value;
                    break;
                default:
                    meta.logger.warn(`zigbee-herdsman-converters:TS0222 Unrecognized DP #${dp} with data ${JSON.stringify(dpValue)}`);
                }
            }
            return result;
        },
    },
    ZM35HQ_battery: {
        cluster: 'manuSpecificTuya',
        type: ['commandDataReport'],
        convert: (model, msg, publish, options, meta) => {
            const dpValue = tuya.firstDpValue(msg, meta, 'ZM35HQ');
            const dp = dpValue.dp;
            const value = tuya.getDataValue(dpValue);
            if (dp === 4) return {battery: value};
            else {
                meta.logger.warn(`zigbee-herdsman-converters:ZM35HQ: NOT RECOGNIZED DP #${dp} with data ${JSON.stringify(dpValue)}`);
            }
        },
    },
    power_on_behavior: {
        cluster: 'manuSpecificTuya_3',
        type: ['attributeReport', 'readResponse'],
        convert: (model, msg, publish, options, meta) => {
            const attribute = 'powerOnBehavior';
            const lookup = {0: 'off', 1: 'on', 2: 'previous'};

            if (msg.data.hasOwnProperty(attribute)) {
                const property = utils.postfixWithEndpointName('power_on_behavior', msg, model, meta);
                return {[property]: lookup[msg.data[attribute]]};
            }
        },
    },
    zb_sm_cover: {
        cluster: 'manuSpecificTuya',
        type: ['commandDataReport', 'commandDataResponse'],
        convert: (model, msg, publish, options, meta) => {
            const result = {};
            for (const dpValue of msg.data.dpValues) {
                const dp = dpValue.dp;
                const value = tuya.getDataValue(dpValue);

                switch (dp) {
                case tuya.dataPoints.coverPosition: // Started moving to position (triggered from Zigbee)
                case tuya.dataPoints.coverArrived: { // Arrived at position
                    const invert = (meta.state) ? !meta.state.invert_cover : false;
                    const position = invert ? 100 - (value & 0xFF) : (value & 0xFF);
                    if (position > 0 && position <= 100) {
                        result.position = position;
                        result.state = 'OPEN';
                    } else if (position == 0) { // Report fully closed
                        result.position = position;
                        result.state = 'CLOSE';
                    }
                    break;
                }
                case 1: // report state
                    result.state = {0: 'OPEN', 1: 'STOP', 2: 'CLOSE'}[value];
                    break;
                case tuya.dataPoints.motorDirection: // reverse direction
                    result.reverse_direction = (value == 1);
                    break;
                case 10: // cycle time
                    result.cycle_time = value;
                    break;
                case 101: // model
                    result.motor_type = {0: '', 1: 'AM0/6-28R-Sm', 2: 'AM0/10-19R-Sm',
                        3: 'AM1/10-13R-Sm', 4: 'AM1/20-13R-Sm', 5: 'AM1/30-13R-Sm'}[value];
                    break;
                case 102: // cycles
                    result.cycle_count = value;
                    break;
                case 103: // set or clear bottom limit
                    result.bottom_limit = {0: 'SET', 1: 'CLEAR'}[value];
                    break;
                case 104: // set or clear top limit
                    result.top_limit = {0: 'SET', 1: 'CLEAR'}[value];
                    break;
                case 109: // active power
                    result.active_power = value;
                    break;
                case 115: // favorite_position
                    result.favorite_position = (value != 101) ? value : null;
                    break;
                case 116: // report confirmation
                    break;
                case 121: // running state
                    result.motor_state = {0: 'OPENING', 1: 'STOPPED', 2: 'CLOSING'}[value];
                    result.running = (value !== 1) ? true : false;
                    break;
                default: // Unknown code
                    meta.logger.warn(`zb_sm_tuya_cover: Unhandled DP #${dp} for ${meta.device.manufacturerName}:
                    ${JSON.stringify(dpValue)}`);
                }
            }
            return result;
        },
    },
    x5h_thermostat: {
        cluster: 'manuSpecificTuya',
        type: ['commandDataResponse', 'commandDataReport'],
        convert: (model, msg, publish, options, meta) => {
            const dpValue = tuya.firstDpValue(msg, meta, 'x5h_thermostat');
            const dp = dpValue.dp;
            const value = tuya.getDataValue(dpValue);

            switch (dp) {
            case tuya.dataPoints.x5hState: {
                return {system_mode: value ? 'heat' : 'off'};
            }
            case tuya.dataPoints.x5hWorkingStatus: {
                return {running_state: value ? 'heat' : 'idle'};
            }
            case tuya.dataPoints.x5hSound: {
                return {sound: value ? 'ON' : 'OFF'};
            }
            case tuya.dataPoints.x5hFrostProtection: {
                return {frost_protection: value ? 'ON' : 'OFF'};
            }
            case tuya.dataPoints.x5hWorkingDaySetting: {
                return {week: tuya.thermostatWeekFormat[value]};
            }
            case tuya.dataPoints.x5hFactoryReset: {
                if (value) {
                    clearTimeout(globalStore.getValue(msg.endpoint, 'factoryResetTimer'));
                    const timer = setTimeout(() => publish({factory_reset: 'OFF'}), 60 * 1000);
                    globalStore.putValue(msg.endpoint, 'factoryResetTimer', timer);
                    meta.logger.info('The thermostat is resetting now. It will be available in 1 minute.');
                }

                return {factory_reset: value ? 'ON' : 'OFF'};
            }
            case tuya.dataPoints.x5hTempDiff: {
                return {deadzone_temperature: parseFloat((value / 10).toFixed(1))};
            }
            case tuya.dataPoints.x5hProtectionTempLimit: {
                return {heating_temp_limit: value};
            }
            case tuya.dataPoints.x5hBackplaneBrightness: {
                const lookup = {0: 'off', 1: 'low', 2: 'medium', 3: 'high'};

                if (value >= 0 && value <= 3) {
                    globalStore.putValue(msg.endpoint, 'brightnessState', value);
                    return {brightness_state: lookup[value]};
                }

                // Sometimes, for example on thermostat restart, it sends message like:
                // {"dpValues":[{"data":{"data":[90],"type":"Buffer"},"datatype":4,"dp":104}
                // It doesn't represent any brightness value and brightness remains the previous value
                const lastValue = globalStore.getValue(msg.endpoint, 'brightnessState') || 1;
                return {brightness_state: lookup[lastValue]};
            }
            case tuya.dataPoints.x5hWeeklyProcedure: {
                const periods = [];
                const periodSize = 4;
                const periodsNumber = 8;

                for (let i = 0; i < periodsNumber; i++) {
                    const hours = value[i * periodSize];
                    const minutes = value[i * periodSize + 1];
                    const tempHexArray = [value[i * periodSize + 2], value[i * periodSize + 3]];
                    const tempRaw = Buffer.from(tempHexArray).readUIntBE(0, tempHexArray.length);
                    const strHours = hours.toString().padStart(2, '0');
                    const strMinutes = minutes.toString().padStart(2, '0');
                    const temp = parseFloat((tempRaw / 10).toFixed(1));
                    periods.push(`${strHours}:${strMinutes}/${temp}`);
                }

                const schedule = periods.join(' ');
                return {schedule};
            }
            case tuya.dataPoints.x5hChildLock: {
                return {child_lock: value ? 'LOCK' : 'UNLOCK'};
            }
            case tuya.dataPoints.x5hSetTemp: {
                const setpoint = parseFloat((value / 10).toFixed(1));
                globalStore.putValue(msg.endpoint, 'currentHeatingSetpoint', setpoint);
                return {current_heating_setpoint: setpoint};
            }
            case tuya.dataPoints.x5hSetTempCeiling: {
                return {upper_temp: value};
            }
            case tuya.dataPoints.x5hCurrentTemp: {
                const temperature = value & (1 << 15) ? value - (1 << 16) + 1 : value;
                return {local_temperature: parseFloat((temperature / 10).toFixed(1))};
            }
            case tuya.dataPoints.x5hTempCorrection: {
                return {local_temperature_calibration: parseFloat((value / 10).toFixed(1))};
            }
            case tuya.dataPoints.x5hMode: {
                const lookup = {0: 'manual', 1: 'program'};
                return {preset: lookup[value]};
            }
            case tuya.dataPoints.x5hSensorSelection: {
                const lookup = {0: 'internal', 1: 'external', 2: 'both'};
                return {sensor: lookup[value]};
            }
            case tuya.dataPoints.x5hOutputReverse: {
                return {output_reverse: value};
            }
            default: {
                meta.logger.warn(`fromZigbee:x5h_thermostat: Unrecognized DP #${dp} with data ${JSON.stringify(dpValue)}`);
            }
            }
        },
    },
    humidity10: {
        cluster: 'msRelativeHumidity',
        type: ['attributeReport', 'readResponse'],
        options: [exposes.options.precision('humidity'), exposes.options.calibration('humidity')],
        convert: (model, msg, publish, options, meta) => {
            const humidity = parseFloat(msg.data['measuredValue']) / 10.0;
            if (humidity >= 0 && humidity <= 100) {
                return {humidity: utils.calibrateAndPrecisionRoundOptions(humidity, options, 'humidity')};
            }
        },
    },
    temperature_unit: {
        cluster: 'manuSpecificTuya_2',
        type: ['attributeReport', 'readResponse'],
        convert: (model, msg, publish, options, meta) => {
            const result = {};
            if (msg.data.hasOwnProperty('57355')) {
                result.temperature_unit = {'0': 'celsius', '1': 'fahrenheit'}[msg.data['57355']];
            }
            return result;
        },
    },
};

module.exports = [
    
    {
        zigbeeModel: ['kud7u2l'],
        fingerprint: [
            {modelID: 'TS0601', manufacturerName: '_TZE200_ckud7u2l'},
            {modelID: 'TS0601', manufacturerName: '_TZE200_ywdxldoj'},
            {modelID: 'TS0601', manufacturerName: '_TZE200_cwnjrr72'},
            {modelID: 'TS0601', manufacturerName: '_TZE200_pvvbommb'},
            {modelID: 'TS0601', manufacturerName: '_TZE200_9sfg7gm0'}, // HomeCloud
            {modelID: 'TS0601', manufacturerName: '_TZE200_2atgpdho'}, // HY367
            {modelID: 'TS0601', manufacturerName: '_TZE200_cpmgn2cf'},
            {modelID: 'TS0601', manufacturerName: '_TZE200_4eeyebrt'}, // Immax 07732B
            {modelID: 'TS0601', manufacturerName: '_TZE200_8whxpsiw'}, // EVOLVEO
            {modelID: 'TS0601', manufacturerName: '_TZE200_chyvmhay'}, // Silvercrest / Lidl
        ],
        model: 'TS0601_thermostat',
        vendor: 'TuYa',
        description: 'Radiator valve with thermostat',
        whiteLabel: [
            {vendor: 'Moes', model: 'HY368'},
            {vendor: 'Moes', model: 'HY369RT'},
            {vendor: 'SHOJZJ', model: '378RT'},
            {vendor: 'Silvercrest', model: 'TVR01'},
            {vendor: 'Immax', model: '07732B'},
            {vendor: 'Evolveo', model: 'Heat M30'},
        ],
        meta: {tuyaThermostatPreset: tuya.thermostatPresets, tuyaThermostatSystemMode: tuya.thermostatSystemModes3},
        ota: ota.zigbeeOTA,
        onEvent: tuya.onEventSetLocalTime,
        fromZigbee: [fz.tuya_thermostat, fz.ignore_basic_report, fz.ignore_tuya_set_time],
        toZigbee: [tz.tuya_thermostat_child_lock, tz.tuya_thermostat_window_detection, tz.tuya_thermostat_valve_detection,
            tz.tuya_thermostat_current_heating_setpoint, tz.tuya_thermostat_auto_lock,
            tz.tuya_thermostat_calibration, tz.tuya_thermostat_min_temp, tz.tuya_thermostat_max_temp,
            tz.tuya_thermostat_boost_time, tz.tuya_thermostat_comfort_temp, tz.tuya_thermostat_eco_temp,
            tz.tuya_thermostat_force_to_mode, tz.tuya_thermostat_force, tz.tuya_thermostat_preset, tz.tuya_thermostat_away_mode,
            tz.tuya_thermostat_window_detect, tz.tuya_thermostat_schedule, tz.tuya_thermostat_week, tz.tuya_thermostat_away_preset,
            tz.tuya_thermostat_schedule_programming_mode],
        exposes: [
            e.child_lock(), e.window_detection(),
            exposes.binary('window_open', ea.STATE).withDescription('Window open?'),
            e.battery_low(), e.valve_detection(), e.position(),
            exposes.climate().withSetpoint('current_heating_setpoint', 5, 35, 0.5, ea.STATE_SET)
                .withLocalTemperature(ea.STATE).withSystemMode(['heat', 'auto', 'off'], ea.STATE_SET,
                    'Mode of this device, in the `heat` mode the TS0601 will remain continuously heating, i.e. it does not regulate ' +
                    'to the desired temperature. If you want TRV to properly regulate the temperature you need to use mode `auto` ' +
                    'instead setting the desired temperature.')
                .withLocalTemperatureCalibration(-9, 9, 1, ea.STATE_SET)
                .withPreset(['schedule', 'manual', 'boost', 'complex', 'comfort', 'eco'])
                .withRunningState(['idle', 'heat'], ea.STATE),
            e.auto_lock(), e.away_mode(), e.away_preset_days(), e.boost_time(), e.comfort_temperature(), e.eco_temperature(), e.force(),
            e.max_temperature(), e.min_temperature(), e.away_preset_temperature(),
            exposes.composite('programming_mode').withDescription('Schedule MODE ⏱ - In this mode, ' +
                    'the device executes a preset week programming temperature time and temperature.')
                .withFeature(e.week())
                .withFeature(exposes.text('workdays_schedule', ea.STATE_SET))
                .withFeature(exposes.text('holidays_schedule', ea.STATE_SET))],
    },
];
