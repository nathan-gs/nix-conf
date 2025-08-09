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
            # TODO: remove nkeys_ floor1_fen_window & roaming_roaming
            attributes.entity_id = ''
              {% set ignore_seconds = 300 %}
              {% set ignore_ts = (now().timestamp() - ignore_seconds)|as_datetime %}
              {% set entities = states
                  |rejectattr('domain','in',['button','event','group','input_button','input_text','scene', 'media_player', 'update'])
                  |rejectattr('last_changed','ge',ignore_ts) 
                  |rejectattr('entity_id', 'contains', 'dsmr_current')
                  |rejectattr('entity_id', 'contains', 'dsmr_day')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_gas_currently')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_gas_read_at')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_gas_currently')
                  |rejectattr('entity_id', 'contains', 'dsmr_consumption_quarter_hour_peak_electricity_read')
                  |rejectattr('entity_id', 'contains', 'dsmr_reading_electricity_delivered_2_cost_2')
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
                  |rejectattr('entity_id', 'contains', 'plex_')
                  |rejectattr('entity_id', 'contains', 'nkeys_') 
                  |rejectattr('entity_id', 'contains', 'floor1_fen_window_') 
                  |rejectattr('entity_id', 'contains', 'floor1_nikolai_temperature_na_battery_low') 
                  |rejectattr('entity_id', 'contains', 'garden_garden_temperature_noordkant_battery_low') 
                  |rejectattr('entity_id', 'contains', 'garden_garden_temperature_grasmaaier_battery_low') 
                  |rejectattr('entity_id', 'contains', 'roaming_roaming') 
                  |rejectattr('entity_id', 'contains', '_kerstboom')                 
                  |rejectattr('entity_id', 'contains', 'floor1_fen_metering_plug_deken')                 
                  |rejectattr('entity_id', 'contains', 'floor0_keuken_sonos')
                  |rejectattr('entity_id', 'contains', 'garden_garden_plug_pomp')
                  |rejectattr('entity_id', 'contains', 'all_standby_power')
                  |rejectattr('entity_id', 'contains', '_battery_range')
                  |rejectattr('entity_id', 'contains', '_countdown')
                  |rejectattr('entity_id', 'contains', 'zigbee2mqtt_bridge_permit_join_timeout')                  
                  |rejectattr('entity_id', 'contains', 'irceline_linkeroever')
                  |rejectattr('entity_id', 'contains', 'device_tracker')
                  |rejectattr('entity_id', 'contains', '_internet_access')
                  |rejectattr('entity_id', 'contains', '_window_')
                  |rejectattr('entity_id', 'contains', 'conversation.home_assistant')
                  |rejectattr('entity_id', 'contains', 'sensor.irceline_')
                  |rejectattr('entity_id', 'contains', 'select.floor0_living_fire_alarm_main_alarm')
                  |rejectattr('entity_id', 'contains', 'sensor.garden_garden_button_pomp_battery')
                  |rejectattr('entity_id', 'contains', 'sensor.rainfall_5d')
                  |rejectattr('entity_id', 'contains', 'indego_325608617')
                  |rejectattr('entity_id', 'contains', 'spotify_')
                  |rejectattr('entity_id', 'contains', 'sensor.all_standby_energy')
                  |rejectattr('entity_id', 'contains', '_power_outage_memory')
                  |rejectattr('entity_id', 'contains', 'garden_voordeur_light_plug_cirkel')
                  |rejectattr('entity_id', 'contains', 'sensor.electricity_cost_engie_drive_offpeak_kwh_energycomponent')
                  |rejectattr('entity_id', 'contains', 'sensor.electricity_cost_engie_drive_peak_kwh_energycomponent')
                  |rejectattr('entity_id', 'contains', 'sensor.gas_cost_engie_drive_kwh_energycomponent')
                  |rejectattr('entity_id', 'contains', 'electricity_cost_octa')
                  |rejectattr('entity_id', 'contains', 'gas_cost_octa')
                  |rejectattr('entity_id', 'contains', 'floor0_living_rtv_vooraan')
                  |rejectattr('entity_id', 'contains', 'ohme_home_go_target_percentage')
                  |rejectattr('entity_id', 'contains', 'ohme_home_go_ct_reading')
                  |rejectattr('entity_id', 'contains', 'ohme_home_go_next_charge_slot_end')
                  |rejectattr('entity_id', 'contains', 'ohme_home_go_next_charge_slot_start')                
                  |rejectattr('entity_id', 'contains', 'ohme_home_go_charge_mode')                
                  |rejectattr('entity_id', 'contains', 'ohme_home_go_charge_slots')                
                  |rejectattr('entity_id', 'contains', 'sensor.x1_xdrive30e_remaining_fuel')
                  |rejectattr('entity_id', 'contains', 'sensor.backup_')                  
                  |rejectattr('entity_id', 'contains', 'sensor.floor1_roaming_metering_plug_airco')       
                  |rejectattr('entity_id', 'contains', 'select.botje_lamp')                  
                  |rejectattr('entity_id', 'contains', '_rtv_na_away_setting')                  
                  |rejectattr('entity_id', 'contains', 'sensor.x1_xdrive30e_charging_end_time')
                  |rejectattr('entity_id', 'contains', 'sensor.ebusd_bai_modulationtempdesired')
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
            mode = "queued";
          }
      )
    ];


  };
}
