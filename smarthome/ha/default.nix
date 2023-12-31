{ config, pkgs, lib, ha, ... }:

{
  services.home-assistant.config = {
    template = [
      {
        sensor = [
          # Inspired by
          # https://github.com/jazzyisj/unavailable-entities-sensor/
          {
            name = "system/ha/unavailable_entities";
            state = ''
              {% set entities = state_attr(this.entity_id,'entity_id') %}
              {{ entities|count if entities != none else none }}
            '';
            attributes.entity_id = ''
              {% set ignore_seconds = 60 %}
              {% set ignore_ts = (now().timestamp() - ignore_seconds)|as_datetime %}
              {% set entities = states
                  |rejectattr('domain','in',['button','event','group','input_button','input_text','scene'])
                  |rejectattr('last_changed','ge',ignore_ts) 
                  |rejectattr('entity_id', 'contains', 'dsmr_current')
                  |rejectattr('entity_id', 'contains', 'dsmr_day')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_gas_currently')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_gas_read_at')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_gas_currently')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_quarter_hour_peak_electricity_read')
                  |rejectattr('entity_id', 'contains', 'dsmr_meter_stats_')
                  |rejectattr('entity_id', 'contains', 'dsmr_reading_electricity_delivered_1_cost_2')
                  |rejectattr('entity_id', 'contains', 'dsmr_reading_extra_device_delivered')
                  |rejectattr('entity_id', 'contains', 'dsmr_reading_timestamp')
                  |rejectattr('entity_id', 'contains', '_lock')
                  |rejectattr('entity_id', 'contains', '_indicator_mode')
                  |rejectattr('entity_id', 'contains', '_power_on_behavior')
                  |rejectattr('entity_id', 'contains', 'botje_energy_meter')
                  |rejectattr('entity_id', 'contains', 'botje_power_meter')
                  |rejectattr('entity_id', 'contains', 'dishwasher_end_time')
                  |rejectattr('entity_id', 'contains', 'dishwasher_start_time')
                  |rejectattr('entity_id', 'contains', 'ebusd_370_b51000tempdesiredloadingpump')
                  |rejectattr('entity_id', 'contains', 'ebusd_bai_setmode_hwcflowtempdesired')
                  |rejectattr('entity_id', 'contains', 'ebusd_bai_setmode_hwcflowtempdesired')
                  |rejectattr('entity_id', 'contains', 'ebusd_bai_status01_temp1_3')
                  |rejectattr('entity_id', 'contains', 'ebusd_bai_status01_temp2')
                  |rejectattr('entity_id', 'contains', 'ebusd_bai_status16')
                  |rejectattr('entity_id', 'contains', 'ebusd_bai_status')
                  |rejectattr('entity_id', 'contains', 'ebusd_bai_vortexflowsensor')
                  |rejectattr('entity_id', 'contains', 'openweathermap_dew_point')
                  |rejectattr('entity_id', 'contains', 'openweathermap_forecast_temperature_low')
                  |rejectattr('entity_id', 'contains', 'openweathermap_uv_index')
                  
              %}
              {{ entities|map(attribute='entity_id')|reject('has_value')|list|sort }}
            '';
            icon = "{{ iif(states(this.entity_id)|int(-1) > 0,'mdi:alert-circle','mdi:check-circle') }}";
            state_class = "measurement";
          }
        ];
      }
    ];

    "automation manual" = [
      (
        ha.automation "system/ha/unavailable_entities.notify"
          {
            triggers = [ (ha.trigger.state "sensor.system_ha_unavailable_entities") ];
            actions = [
              (
                ha.action.conditional
                [(ha.condition.below "sensor.system_ha_unavailable_entities" 1)]
                [ (ha.action.persistent_notification.dismiss "system_ha_unavailable_entities") ]
                [ (ha.action.persistent_notification.create "system_ha_unavailable_entities" "Unavailable Entities" ''{{ state_attr('sensor.system_ha_unavailable_entities','entity_id')|join('\n') }}'') ]
              )
            ];
          }
      )
    ];


  };
}
