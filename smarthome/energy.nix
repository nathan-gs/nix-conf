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

    sensor = [
      {
        platform = "scrape";
        resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
        name = "electricity_cost_peak_kwh_energycomponent";
        select = "table :has(> th:-soup-contains(Dagtarief)) td";
        unit_of_measurement = "€/kWh";
        value_template = "{{ (value | float) / 100 }}";
        scan_interval = 3600;
      }
      {
        platform = "scrape";
        resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
        name = "electricity_cost_offpeak_kwh_energycomponent";
        select = "table :has(> th:-soup-contains(Nachttarief)) td";
        unit_of_measurement = "€/kWh";
        value_template = "{{ (value | float) / 100 }}";
        scan_interval = 3600;
      }
      {
        platform = "scrape";
        resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
        name = "gas_cost_kwh_energycomponent";
        select = "table :has(> th:-soup-contains(per)) td";
        unit_of_measurement = "€/kWh";
        value_template = "{{ (value | float) / 100 }}";
        scan_interval = 3600;
      }      
    ];
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
          state = "{{ states('sensor.electricity_delivery') | float > 2800 }}";
        };
      }
    ];

  };

in
{

  template = cost.template ++ gas.template ++ electricity.template;
  sensor = cost.sensor ++ electricity.sensor;
  utility_meter = gas.utility_meter // electricity.utility_meter;
  customize = electricity.customize;
}
