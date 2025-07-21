let 

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
            state_class = "total";
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
            state_class = "total";
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
            name = "electricity_grid_consumed_power";
            state = "{{ states('sensor.dsmr_reading_electricity_currently_delivered') | float(0) * 1000 }}";
            unit_of_measurement = "W";
            attributes.workaround = ''{{ now().minute }}'';
            state_class = "measurement";
          }
          {
            name = "electricity_grid_returned_power";
            state = "{{ states('sensor.dsmr_reading_electricity_currently_returned') | float(0) * 1000 }}";
            unit_of_measurement = "W";
            attributes.workaround = ''{{ now().minute }}'';
            state_class = "measurement";
          }
          {
            name = "electricity_total_power";
            state = "{{ states('sensor.solis_total_consumption_power') | float(0) }}";
            unit_of_measurement = "W";
            attributes.workaround = ''{{ now().minute }}'';
            state_class = "measurement";
          }
          {
            name = "electricity_battery_power";
            state = "{{ states('sensor.solis_battery_power') | float(0) }}";
            unit_of_measurement = "W";
            attributes.workaround = ''{{ now().minute }}'';
            state_class = "measurement";
          }
          {
            name = "electricity_solar_power";
            state = "{{ states('sensor.solar_currently_produced') | float(0) * 1000 }}";
            unit_of_measurement = "W";
            attributes.workaround = ''{{ now().minute }}'';
            state_class = "measurement";
          }
        ];
      }
      
    ];

    automations = [ ];

  };

in
{

  services.home-assistant = {
    config."automation manual" = []
      ++ electricity.automations;

    config.homeassistant.customize = {} 
      // electricity.customize;

    config.sensor = []
      ++ electricity.sensor;

    config.utility_meter = { } 
      //  gas.utility_meter 
      // electricity.utility_meter;

    config.template = [] 
      ++ gas.template 
      ++ electricity.template;

  };
}
