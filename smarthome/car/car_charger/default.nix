{ config, pkgs, lib, ha, ... }:

{

  imports = [
    ./tuya.nix
  ];

  services.home-assistant.config = {

    template = [
      {
        trigger = [
          {
            platform = "homeassistant";
            event = "start";
          }
          {
            platform = "time_pattern";
            hours = "*";
            minutes = "59";
            seconds = "50";
          }
        ];
        sensor = [
          {
            name = "car_charger_solar_revenue_previous";
            unique_id = "car_charger_solar_revenue_previous";
            state = ''        
              {{ states('sensor.car_charger_solar_revenue')| float(0) }}
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
          {
            name = "car_charger_grid_revenue_previous";
            unique_id = "car_charger_grid_revenue_previous";
            state = ''        
              {{ states('sensor.car_charger_grid_revenue')| float(0) }}
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
          {
            name = "car_charger_cost_previous";
            unique_id = "car_charger_cost_previous";
            state = ''
              {{ states('sensor.car_charger_cost')| float(0) }}              
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }       
        ];
      }   
      {
        trigger = {
          platform = "time_pattern";
          hours = "*";
          minutes = "*";
          seconds = "1";
        };
        sensor = [
          {
            name = "car_charger_solar_revenue";
            unique_id = "car_charger_solar_revenue";
            state = ''
              {% set hourly = states('sensor.car_charger_solar_revenue_hourly') %}
              {% set previous = states('sensor.car_charger_solar_revenue_previous') | float(0) %}
              {% if hourly not in ['unavailable', 'unknown', 'none'] %}
                {{ previous + (hourly | float) | round(2) }}       
              {% else %}
                {{ this.state | float }}
              {% endif %}    
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
          {
            name = "car_charger_grid_revenue";
            unique_id = "car_charger_grid_revenue";
            state = ''
              {% set hourly = states('sensor.car_charger_grid_revenue_hourly') %}
              {% set previous = states('sensor.car_charger_grid_revenue_previous') | float(0) %}
              {% if hourly not in ['unavailable', 'unknown', 'none'] %}
                {{ previous + (hourly | float) | round(2) }}
              {% else %}
                {{ this.state | float(0) }}
              {% endif %}
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
          {
            name = "car_charger_cost";
            unique_id = "car_charger_cost";
            state = ''
              {% set hourly = states('sensor.car_charger_cost_hourly') %}
              {% set previous = states('sensor.car_charger_cost_previous') | float(0) %}
              {% if hourly not in ['unavailable', 'unknown', 'none'] %}
                {{ previous + (hourly | float) | round(2) }}
              {% else %}
                {{ this.state | float(0) }}
              {% endif %}
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
        ];
      }
      {
        sensor = [
          {
            name = "car_charger_cost_hourly";
            unique_id = "car_charger_cost_hourly";
            device_class = "monetary";
            state = ''
              {% set energy = states('sensor.car_charger_energy_hourly') %}
              {% set creg = states('sensor.electricity_injection_creg_kwh') %}
              {% if energy not in ['unavailable', 'unknown', 'none'] and creg not in ['unavailable', 'unknown', 'none', 0] %}
                {{ (energy | float(0) * creg | float(0)) | round(2) }}
              {% else %}
                {{ this.state | float(0) }}
              {% endif %}
            '';
            unit_of_measurement = "€";
            icon = "mdi:car-electric-outline";
            state_class = "total";
          }
          {
            name = "car_charger_solar_revenue_hourly";
            unique_id = "car_charger_solar_revenue_hourly";
            device_class = "monetary";
            state = ''
              {% set energy = states('sensor.car_charger_solar_energy_hourly') %}
              {% set injection_rev = states('sensor.electricity_injection_creg_kwh') %}
              {% if energy not in ['unavailable', 'unknown', 'none'] and injection_rev not in ['unavailable', 'unknown', 'none', 0] %}
                {{ (energy | float(0) * injection_rev | float(0)) | round(2) }}
              {% else %}
                {{ this.state | float(0) }}
              {% endif %}
            '';
            unit_of_measurement = "€";
            icon = "mdi:car-electric-outline";
            state_class = "total";
          }
          {
            name = "car_charger_grid_revenue_hourly";
            unique_id = "car_charger_grid_revenue_hourly";
            device_class = "monetary";
            state = ''
              {% set energy = states('sensor.car_charger_grid_energy_hourly') %}
              {% set injection_rev = states('sensor.electricity_injection_creg_kwh')  %}
              {% set energy_cost = states('sensor.energy_electricity_cost') %}
              {% if (energy not in ['unavailable', 'unknown', 'none']) and (injection_rev not in ['unavailable', 'unknown', 'none', 0]) and (energy_cost not in ['unavailable', 'unknown', 'none', 0]) %}
               {% set rev = (injection_rev | float(0)) - (energy_cost | float(0)) %}
                {{ (energy | float(0) * rev) | round(2) }}
              {% else %}
                {{ this.state | float(0) }}
              {% endif %}
            '';
            unit_of_measurement = "€";
            icon = "mdi:car-electric-outline";
            state_class = "total";
          }
          {
            name = "car_charger_revenue_hourly";
            unique_id = "car_charger_revenue_hourly";
            device_class = "monetary";
            state = ''
              {% set grid = states('sensor.car_charger_grid_revenue_hourly') | float(0) %}
              {% set solar = states('sensor.car_charger_solar_revenue_hourly') | float(0) %}
              {{ grid + solar | round(2) }}
            '';
            unit_of_measurement = "€";
            icon = "mdi:car-electric-outline";
            state_class = "total";
          }
          {
            name = "car_charger_revenue";
            unique_id = "car_charger_revenue";
            state = ''              
              {% set grid = states('sensor.car_charger_grid_revenue') | float(0) %}
              {% set solar = states('sensor.car_charger_solar_revenue') | float(0) %}
              {{ grid + solar | round(2) }}
            '';
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total";
            icon = "mdi:car-electric-outline";
          }
        ];        

        binary_sensor = [
          {
            name = "car_charger_charging";
            unique_id = "car_charger_charging";
            device_class = "plug";
            state = ''
              {{ states('sensor.system_car_charger_metering_plug_measure_power') | int(0) > 5 }}
            '';
          }
        ];
      }
    ];

    utility_meter = {
      car_charger_grid_revenue_daily = {
        source = "sensor.car_charger_grid_revenue";
        cycle = "daily";
        periodically_resetting = false;
      };
      car_charger_grid_revenue_monthly = {
        source = "sensor.car_charger_grid_revenue";
        cycle = "monthly";
        periodically_resetting = false;
      };
      car_charger_solar_revenue_daily = {
        source = "sensor.car_charger_solar_revenue";
        cycle = "daily";
        periodically_resetting = false;
      };
      car_charger_solar_revenue_monthly = {
        source = "sensor.car_charger_solar_revenue";
        cycle = "monthly";
        periodically_resetting = false;
      };
      car_charger_revenue_daily = {
        source = "sensor.car_charger_revenue";
        cycle = "daily";
        periodically_resetting = false;
      };
      car_charger_revenue_monthly = {
        source = "sensor.car_charger_revenue";
        cycle = "monthly";
        periodically_resetting = false;
      };
      car_charger_cost_daily = {
        source = "sensor.car_charger_cost";
        cycle = "daily";
        periodically_resetting = false;
      };
      car_charger_cost_monthly = {
        source = "sensor.car_charger_cost";
        cycle = "monthly";
        periodically_resetting = false;
      };
    };

    "automation manual" = [
    ];

    powercalc = {
      sensors = [
        {
          name = "car_charger";
          unique_id = "car_charger";
          entity_id = "binary_sensor.car_charger_charging";
          fixed.power = ''            
            {{ states('sensor.system_car_charger_metering_plug_measure_power') | int(0) }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
        {
          name = "car_charger_solar";
          unique_id = "car_charger_solar";
          entity_id = "binary_sensor.car_charger_charging";
          fixed.power = ''            
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = (states('sensor.car_charger_power') | int(0)) %}
            {% set power = (consumptionPower - import_from_grid) %}
            {% if power < 0 %}
              {% set power = 0 %}
            {% endif %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
        {
          name = "car_charger_grid";
          entity_id = "binary_sensor.car_charger_charging";
          unique_id = "car_charger_grid";
          fixed.power = ''
            {% set import_from_grid = states('sensor.electricity_grid_consumed_power') | float(1500) %}
            {% set consumptionPower = (states('sensor.car_charger_power') | int(0)) %}
            {% set power = min(import_from_grid, consumptionPower) %}
            {% if power < 0 %}
              {% set power = 0 %}
            {% endif %}
            {{ power }}
          '';
          create_utility_meters = true;
          utility_meter_types = [ "hourly" "daily" "monthly" ];
        }
      ];
    };

  };
}
