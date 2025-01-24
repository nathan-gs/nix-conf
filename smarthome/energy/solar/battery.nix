{ config, pkgs, lib, ha, ... }:
{

  services.home-assistant.config = {


    powercalc = {
      sensors = [ ];
    };

    #
    # The idea is every percentage represents a fixed kWh (dis)charging energy. 
    # The US5000 has 4800Wh, the US3000C has 3552Wh.
    #

    template = [
      {
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.battery_percentage_change";        
          }
        ];
        sensor = [
          {
            name = "battery_charging_energy";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% if battery_change > 0 %}
                {{ (( this.state | float ) + ((battery_change * (48 + 35)) / 1000)) | round(2) }}
              {% else %}
                {{ this.state | float }}
              {% endif %}
            '';
            device_class = "energy";
            state_class = "total_increasing";
            unit_of_measurement = "kWh";
          }
          {
            name = "battery_discharging_energy";
            state = ''
              {% set battery_change = states('sensor.battery_percentage_change') | float(0) %}
              {% if battery_change < 0 %}
                {{ ((this.state | float) + ((battery_change * -1 * ((48 + 35) * 0.98)) / 1000)) | round(2) }}
              {% else %}
                {{ this.state | float }}
              {% endif %}
            '';
            device_class = "energy";
            state_class = "total_increasing";
            unit_of_measurement = "kWh";
          }
        ];
      }
    ];

    input_boolean = {
      solar_battery_charge_offpeak = {
        name = "solar/battery/charge_offpeak";
        icon = "mdi:battery";
      };
    };

    

    mqtt.sensor = [
      {
        name = "battery_percentage_change";
        state_topic = "solar/battery/change";
        value_template = "{{ value_json.value }}";
        unit_of_measurement = "%";
        json_attributes_topic = "solar/battery/change";
        json_attributes_template = "{{ value_json | tojson }}";
        state_class = "measurement";
      }
    ];

    "automation manual" = [
      {
        id = "battery_change";
        alias = "battery_change";
        trigger = [
          {
            platform = "state";
            entity_id = "sensor.solis_remaining_battery_capacity";
          }
        ];
        condition = ''
          {{ not (is_state('sensor.solis_remaining_battery_capacity', 'unknown') or is_state('sensor.solis_remaining_battery_capacity', 'unavailable') or trigger.from_state.state | int(0) == 0) }}
        '';
        action = [
          (
            ha.action.mqtt_publish "solar/battery/change" 
              ''
                {
                  "from":{{ trigger.from_state.state | int(0) }},
                  "to": {{ trigger.to_state.state | int(0) }},
                  "value": {{ (trigger.to_state.state | int(0)) - (trigger.from_state.state | int(0)) }}
                }
              ''
              true
          )          
        ];
        mode = "single";
      }
      (ha.automation "solar/battery/charge" {
        triggers = [(ha.trigger.at "05:00:00")];
        conditions = [
          (ha.condition.on "input_boolean.solar_battery_charge_offpeak")
          (ha.condition.off "binary_sensor.electricity_high_usage")
        ];
        actions = [
          (ha.action.set_value "number.solar_battery_maxgridpower" 1200)
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.solar_battery_forcechargesoc" ''20'')
          (ha.action.delay "00:00:30")
          (
            ha.action.conditional 
            [
              (ha.condition.template ''{{ states('sensor.energy_production_today_remaining') | int(0) > 8 }}'')
            ]
            [
              (ha.action.set_value "number.solar_battery_overdischargesoc" ''20'')
            ]
            [
              (ha.action.set_value "number.solar_battery_overdischargesoc" ''25'')
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
          (ha.action.set_value "number.solar_battery_maxgridpower" 300)     
          (ha.action.delay "00:00:30")
          (ha.action.set_value "number.solar_battery_overdischargesoc" ''{{ states('sensor.solar_battery_overdischargesoc_target') | int(20) }}'')
        ];
        mode = "queued";
      })
    ];


  };
}
