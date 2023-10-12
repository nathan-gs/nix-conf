let 
  cost = {
    template = [  
      {
        sensor = [
          {
            name = "gas_cost_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal tax + federal accijns + nettarifs + transport
            state = "{{ ( states('sensor.gas_cost_kwh_energycomponent') | float ) + (0.1058 / 100) + (0.0572 / 100) + (2.07 / 100) + (1.41 / 1000) }}";
          }
          {
            name = "gas_cost_m3";
            unit_of_measurement = "€/m³";
            state = "{{ ( states('sensor.gas_cost_kwh') | float ) * 11.60}}";
          }            
          {
            name = "electricity_cost_peak_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
            state = "{{ ( states('sensor.electricity_cost_peak_kwh_energycomponent') | float ) + (1.44160 / 100) + (9.42 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
          }
          {
            name = "electricity_cost_offpeak_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
            state = "{{ ( states('sensor.electricity_cost_offpeak_kwh_energycomponent') | float ) + (1.44160 / 100) + (6.87 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
          }
        ];
      }
    ];

    scrape = [
      {
        resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
        scan_interval = 3600;
        sensor = [
          {
            name = "electricity_cost_peak_kwh_energycomponent";
            select = "table :has(> th:-soup-contains(Dagtarief)) td";
            value_template = "{{ (value | replace(',', '.') | float) / 100 }}";
            unit_of_measurement = "€/kWh";
          }
          {
            name = "electricity_cost_offpeak_kwh_energycomponent";
            select = "table :has(> th:-soup-contains(Nachttarief)) td";
            unit_of_measurement = "€/kWh";
            value_template = "{{ (value | replace(',', '.') | float) / 100 }}";
          }
          {
            name = "gas_cost_kwh_energycomponent";
            select = "table :has(> th:-soup-contains(per)) td";
            unit_of_measurement = "€/kWh";
            value_template = "{{ (value | replace(',', '.') | float) / 100 }}";
          }
        ];
      }
    ];

    sensor = [];
  };

  gas = {
    utility_meter = {
      gas_delivery = {
        source = "sensor.dsmr_consumption_gas_delivered";
      };
      gas_delivery_daily = {
        source = "sensor.dsmr_consumption_gas_delivered";
        cycle = "daily";
      };
      gas_delivery_hourly = {
        source = "sensor.dsmr_consumption_gas_delivered";
        cycle = "hourly";
      };
      gas_delivery_weekly = {
        source = "sensor.dsmr_consumption_gas_delivered";
        cycle = "weekly";
      };
      gas_delivery_monthly = {
        source = "sensor.dsmr_consumption_gas_delivered";
        cycle = "monthly";
      };
      gas_delivery_yearly = {
        source = "sensor.dsmr_consumption_gas_delivered";
        cycle = "yearly";
      };
    };

    template = [];
  };

  electricity = {
    customize = {
      "sensor.dsmr_reading_electricity_delivered_1" = {
        friendly_name = "Electricity High tariff usage";
      };
      "sensor.dsmr_reading_electricity_delivered_2" = {
        friendly_name = "Electricity Low tariff usage";
      };
      "sensor.dsmr_reading_electricity_returned_1" = {
        friendly_name = "Electricity High tariff returned";
      };
      "sensor.dsmr_reading_electricity_returned_2" = {
        friendly_name = "Electricity Low tariff returned";
      };      
    };


    utility_meter = {
      electricity_peak_delivery = {
        source = "sensor.dsmr_reading_electricity_delivered_1";
      };
      electricity_peak_delivery_daily = {
        source = "sensor.dsmr_reading_electricity_delivered_1";
        cycle = "daily";
      };
      electricity_peak_delivery_hourly = {
        source = "sensor.dsmr_reading_electricity_delivered_1";
        cycle = "hourly";
      };
      electricity_peak_delivery_weekly = {
        source = "sensor.dsmr_reading_electricity_delivered_1";
        cycle = "weekly";
      };
      electricity_peak_delivery_monthly = {
        source = "sensor.dsmr_reading_electricity_delivered_1";
        cycle = "monthly";
      };
      electricity_peak_delivery_yearly = {
        source = "sensor.dsmr_reading_electricity_delivered_1";
        cycle = "yearly";
      };

      electricity_offpeak_delivery = {
        source = "sensor.dsmr_reading_electricity_delivered_2";
      };
      electricity_offpeak_delivery_daily = {
        source = "sensor.dsmr_reading_electricity_delivered_2";
        cycle = "daily";
      };
      electricity_offpeak_delivery_hourly = {
        source = "sensor.dsmr_reading_electricity_delivered_2";
        cycle = "hourly";
      };
      electricity_offpeak_delivery_weekly = {
        source = "sensor.dsmr_reading_electricity_delivered_2";
        cycle = "weekly";
      };
      electricity_offpeak_delivery_monthly = {
        source = "sensor.dsmr_reading_electricity_delivered_2";
        cycle = "monthly";
      };
      electricity_offpeak_delivery_yearly = {
        source = "sensor.dsmr_reading_electricity_delivered_2";
        cycle = "yearly";
      };

      electricity_peak_return = {
        source = "sensor.dsmr_reading_electricity_returned_1";
      };
      electricity_peak_return_daily = {
        source = "sensor.dsmr_reading_electricity_returned_1";
        cycle = "daily";
      };
      electricity_peak_return_15m = {
        source = "sensor.dsmr_reading_electricity_returned_1";
        cron = "*/15 * * * *";
      };
      electricity_peak_return_hourly = {
        source = "sensor.dsmr_reading_electricity_returned_1";
        cycle = "hourly";
      };
      electricity_peak_return_weekly = {
        source = "sensor.dsmr_reading_electricity_returned_1";
        cycle = "weekly";
      };
      electricity_peak_return_monthly = {
        source = "sensor.dsmr_reading_electricity_returned_1";
        cycle = "monthly";
      };
      electricity_peak_return_yearly = {
        source = "sensor.dsmr_reading_electricity_returned_1";
        cycle = "yearly";
      };

      electricity_offpeak_return = {
        source = "sensor.dsmr_reading_electricity_returned_2";
      };
      electricity_offpeak_return_daily = {
        source = "sensor.dsmr_reading_electricity_returned_2";
        cycle = "daily";
      };
      electricity_offpeak_return_hourly = {
        source = "sensor.dsmr_reading_electricity_returned_2";
        cycle = "hourly";
      };
      electricity_offpeak_return_15m = {
        source = "sensor.dsmr_reading_electricity_returned_2";
        cron = "*/15 * * * *";
      };
      electricity_offpeak_return_weekly = {
        source = "sensor.dsmr_reading_electricity_returned_2";
        cycle = "weekly";
      };
      electricity_offpeak_return_monthly = {
        source = "sensor.dsmr_reading_electricity_returned_2";
        cycle = "monthly";
      };
      electricity_offpeak_return_yearly = {
        source = "sensor.dsmr_reading_electricity_returned_2";
        cycle = "yearly";
      };
      electricity_delivery_15m = {
        source = "sensor.electricity_delivery";
        cron = "*/15 * * * *";
      };
    };

    sensor = [
    ];

    template = [
      {
        sensor = [
          {
            name = "electricity_delivery";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_delivery') | float ) + ( states('sensor.electricity_offpeak_delivery') | float ) }}";
          }
          {
            name = "electricity_delivery_hourly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_delivery_hourly') | float ) + ( states('sensor.electricity_offpeak_delivery_hourly') | float ) }}";
          }
          {
            name = "electricity_delivery_daily";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_delivery_daily') | float ) + ( states('sensor.electricity_offpeak_delivery_daily') | float ) }}";
          }
          {
            name = "electricity_delivery_weekly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_delivery_weekly') | float ) + ( states('sensor.electricity_offpeak_delivery_weekly') | float ) }}";
          }
          {
            name = "electricity_delivery_monthly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_delivery_monthly') | float ) + ( states('sensor.electricity_offpeak_delivery_monthly') | float ) }}";
          }
          {
            name = "electricity_delivery_yearly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_delivery_yearly') | float ) + ( states('sensor.electricity_offpeak_delivery_yearly') | float ) }}";
          }

          {
            name = "electricity_return";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_return') | float ) + ( states('sensor.electricity_offpeak_return') | float ) }}";
          }
          {
            name = "electricity_return_hourly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_return_hourly') | float ) + ( states('sensor.electricity_offpeak_return_hourly') | float ) }}";
          }
          {
            name = "electricity_return_daily";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_return_daily') | float ) + ( states('sensor.electricity_offpeak_return_daily') | float ) }}";
          }
          {
            name = "electricity_return_weekly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_return_weekly') | float ) + ( states('sensor.electricity_offpeak_return_weekly') | float ) }}";
          }
          {
            name = "electricity_return_monthly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_return_monthly') | float ) + ( states('sensor.electricity_offpeak_return_monthly') | float ) }}";
          }
          {
            name = "electricity_return_yearly";
            unit_of_measurement = "kWh";
            state = "{{ ( states('sensor.electricity_peak_return_yearly') | float ) + ( states('sensor.electricity_offpeak_return_yearly') | float ) }}";
          }
          
          {
            name = "electricity_delivery_power_15m";
            state = "{{ (states('sensor.electricity_delivery_15m') | float(0)) * 4 | float }}";
            unit_of_measurement = "kW";
          }
          {
            name = "electricity_grid_consumed_power";
            state = "{{ states('sensor.dsmr_reading_electricity_currently_delivered') | float(0) * 1000 }}";
            unit_of_measurement = "W";
          }
          {
            name = "electricity_grid_returned_power";
            state = "{{ states('sensor.dsmr_reading_electricity_currently_returned') | float(0) * 1000 }}";
            unit_of_measurement = "W";
          }
          {
            name = "electricity_total_power";
            state = "{{ states('sensor.solis_total_consumption_power') | float(0) }}";
            unit_of_measurement = "W";
          }
          {
            name = "electricity_battery_power";
            state = "{{ states('sensor.solis_battery_power') | float(0) }}";
            unit_of_measurement = "W";
          }
          {
            name = "electricity_solar_power";
            state = "{{ states('sensor.solar_currently_produced') | float(0) * 1000 }}";
            unit_of_measurement = "W";
          }
        ];
      }
      {
        trigger = {
          platform = "time_pattern";
          minutes = "/15";
        };
        sensor = [
          {
            name = "electricity_delivery_power_monthly_15m_max";
            state = ''
              {% if is_number(states('sensor.electricity_delivery_power_monthly_15m_max')) %}
                {% if ((now().hour == 0) and (now().minute < 15) and (now().day == 1)) %}
                  {{ states('sensor.electricity_delivery_power_15m') | float }}
                {% else %}
                  {% if ((states('sensor.electricity_delivery_power_monthly_15m_max') | float) < (states('sensor.electricity_delivery_power_15m')) | float) %}
                    {{ states('sensor.electricity_delivery_power_15m') or 0 | float }}
                  {% else %}
                    {{ states('sensor.electricity_delivery_power_monthly_15m_max') | float }} 
                  {% endif %}
                {% endif %}
              {% else %}
                0
              {% endif %}
            '';
            unit_of_measurement = "kW";
          }
          {
            name = "electricity_delivery_power_daily_15m_max";
            state = ''
              {% if is_number(states('sensor.electricity_delivery_power_daily_15m_max')) %}
                {% if ((now().hour == 0) and (now().minute < 15)) %}
                  {{ states('sensor.electricity_delivery_power_15m') | float }}
                {% else %}
                  {% if ((states('sensor.electricity_delivery_power_daily_15m_max') | float) < (states('sensor.electricity_delivery_power_15m')) | float) %}
                    {{ states('sensor.electricity_delivery_power_15m') or 0 | float }}
                  {% else %}
                    {{ states('sensor.electricity_delivery_power_daily_15m_max') | float }} 
                  {% endif %}
                {% endif %}
              {% else %}
                0
              {% endif %}
            '';
            unit_of_measurement = "kW";
          }
        ];
      }
      {
        binary_sensor = {
          name = "electricity_delivery_power_max_threshold_reached";
          delay_on = "00:02:00";
          delay_off = "00:01:00";
          state = "{{ (states('sensor.dsmr_reading_electricity_currently_delivered') | float * 1000) > 2800 }}";
        };
      }
    ];

    automations = [
      {
        id = "electricity_delivery_power_max_threshold_reached_send_notification";
        alias = "electricity_delivery_power_max_threshold_reached_send_notification";
        trigger = [
          {
            platform = "state";
            entity_id = "binary_sensor.electricity_delivery_power_max_threshold_reached";
            to = "on";
          }
        ];
        condition = [];
        action = [
          {
            service = "notify.notify";
            data = {
              title = "Electricity Peak; ({{  (states('sensor.dsmr_reading_electricity_currently_delivered') | float * 1000) }}W (max 2800w)";
              message = "Electricity Peak; ({{  (states('sensor.dsmr_reading_electricity_currently_delivered') | float * 1000) }}W (max 2800w)";
            };
          }
        ];
        mode = "single";
      }
    ];

  };

  degreeDays = {
    sensor = [
      
    ];

    template = [
      {
        trigger = {
          platform = "time";
          at = "23:59:01";          
        };
        sensor = [
          {
            name = "degree_day_daily";
            state = ''
              {% set regularized_temp = 18.0 | float %}
              {% set average_outside_temp = states('sensor.outdoor_temperature_24h_avg') | float %}
              {% set dd = regularized_temp - average_outside_temp %}
              {% if dd > 0 %}
                {{ dd }}
              {% else %}
                0
              {% endif %}    
            '';
            unit_of_measurement = "DD";
          }
        ];
      }
      {
        trigger = {
          platform = "time";
          at = "23:59:59";          
        };
        sensor = [
          {
            name = "gas_m3_per_degree_day";
            state = ''
              {% set gas_usage = states('sensor.gas_delivery_daily') | float %}
              {% set dd = states('sensor.degree_day_daily') | float %}
              {% if dd > 0 %}
                {{ gas_usage / dd }}
              {% else %}
                0
              {% endif %}      
            '';
            unit_of_measurement = "m³/DD";
          }
        ];
      }
    ];
  };

in
{
  scrape = cost.scrape;
  template = cost.template ++ gas.template ++ electricity.template ++ degreeDays.template;
  sensor = cost.sensor ++ electricity.sensor ++ degreeDays.sensor;
  utility_meter = gas.utility_meter // electricity.utility_meter;
  customize = electricity.customize;
  automations = [] ++ electricity.automations;
}
