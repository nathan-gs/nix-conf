const fz = require('zigbee-herdsman-converters/converters/fromZigbee');
const tz = require('zigbee-herdsman-converters/converters/toZigbee');
const exposes = require('zigbee-herdsman-converters/lib/exposes');
const reporting = require('zigbee-herdsman-converters/lib/reporting');
//const extend = require('zigbee-herdsman-converters/lib/extend');
const ota = require('zigbee-herdsman-converters/lib/ota');
//const tuya = require('zigbee-herdsman-converters/lib/tuya');
//const utils = require('zigbee-herdsman-converters/lib/utils');

const e = exposes.presets;
const ea = exposes.access;

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