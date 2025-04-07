{ config, pkgs, lib, ha, ... }:

{

  services.home-assistant.config = {

    "automation manual" = [
      (
        ha.automation "garden/lawn_mower.turn_on"
          {
            triggers = [ 
              (ha.trigger.above ''sensor.indego_325608617_battery_percentage'' 90) 
              (ha.trigger.template_for ''{{ states('weather.sxw') not in ['rainy', 'pouring', 'lightning', 'lightning-rainy', 'snowy', 'snowy-rainy', 'hail', 'exceptional'] }}'' "01:00:00" )
              (ha.trigger.above "sensor.outdoor_temperature" 7)
              (ha.trigger.time_pattern_minutes "15")
            ];
            conditions = [
              (ha.condition.on "binary_sensor.indego_325608617_online")
              (ha.condition.above ''sensor.indego_325608617_battery_percentage'' 85)
              (ha.condition.template ''{{ states('weather.sxw') not in ['rainy', 'pouring', 'lightning', 'lightning-rainy', 'snowy', 'snowy-rainy', 'hail', 'exceptional'] }}'')
              (ha.condition.state "sun.sun" "above_horizon")
              (ha.condition.template ''{{ now().weekday() != 6 }}'')
              (
                ha.condition.template ''
                  {% set temp = states('sensor.outdoor_temperature') | float(0) %}
                  {% set humidity = states('sensor.outdoor_humidity') | float(0) %}
                  {{ not (temp < 10 and humidity > 70 and now().hour < 10) }}
                ''
              )
              (ha.condition.between "sensor.outdoor_temperature" 7 28)
              (ha.condition.state "lawn_mower.indego_325608617" "docked")
              (
                # Only run if not completed in last 18h
                ha.condition.template ''
                  {% set last_completed = as_timestamp(states('sensor.indego_325608617_last_completed')) | default(0) %}
                  {% set hours_since = (as_timestamp(now()) - last_completed) / (3600) %}
                  {{ hours_since >= 18 }}
                ''
              )
              # Avg run is 8h, limit to max 3 runs a week
              #(ha.condition.below "sensor.indego_runtime_weekly" 23)
            ];
            actions = [
              {
                service = "lawn_mower.start_mowing";                
                target.entity_id = "lawn_mower.indego_325608617";
              }
            ];
          } 

      )
      (
        ha.automation "garden/lawn_mower.turn_off"
          {
            triggers = [
              (ha.trigger.state_to "weather.sxw" ["rainy" "pouring" "lightning" "lightning-rainy" "snowy" "snowy-rainy" "hail" "exceptional"] )
              (ha.trigger.state_to "sun.sun" "below_horizon")
              #(ha.trigger.above "sensor.indego_runtime_weekly" 23)
              (ha.trigger.template ''
                {% set last_completed = as_timestamp(states('sensor.indego_325608617_last_completed')) | default(0) %}
                {% set hours_since = (as_timestamp(now()) - last_completed) / (3600) %}
                {{ hours_since < 18 }}
              '')              
              (ha.trigger.above "sensor.outdoor_temperature" 28)
              (ha.trigger.below "sensor.outdoor_temperature" 7)
            ];
            conditions = [
              (ha.condition.on "binary_sensor.indego_325608617_online")
              (ha.condition.state "lawn_mower.indego_325608617" "mowing")
            ];
            actions = [
              {
                service = "lawn_mower.dock";                
                target.entity_id = "lawn_mower.indego_325608617";
              }
            ];
          }
      )
    ];
    
    utility_meter = {} // ha.utility_meter "indego_runtime" "sensor.indego_325608617_runtime_total" "weekly";

    recorder = {
      include = {
        entities = [
          "lawn_mower.indego_325608617"         
          "sensor.indego_runtime_weekly"
        ];

        entity_globs = [
          "binary_sensor.indego_325608617_*"
          "sensor.indego_325608617_*"
        ];
      };
    };
  };
}
