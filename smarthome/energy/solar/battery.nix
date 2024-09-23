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
          {
            service = "mqtt.publish";
            data = {
              topic = "solar/battery/change";
              payload_template = ''
                {
                  "from":{{ trigger.from_state.state | int(0) }},
                  "to": {{ trigger.to_state.state | int(0) }},
                  "value": {{ (trigger.to_state.state | int(0)) - (trigger.from_state.state | int(0)) }}
                }
              '';
              retain = true;
            };
          }
        ];
        mode = "single";
      }
    ];


  };
}
