{ config, pkgs, lib, ha, ... }:
{

  # https://try.jsoup.org/

  services.home-assistant.config = {

    template = [  
      {
        sensor = [
          {
            name = "gas_cost_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal tax + federal accijns + nettarifs + transport
            state = "{{ ( states('sensor.gas_cost_kwh_energycomponent') | float ) + (0.1058 / 100) + (0.0572 / 100) + (2.07 / 100) + (1.41 / 1000) }}";
            state_class = "measurement";
          }
          {
            name = "gas_cost_m3";
            unit_of_measurement = "€/m³";
            state = "{{ ( states('sensor.gas_cost_kwh') | float ) * 11.60}}";
            state_class = "measurement";
          }            
          {
            name = "electricity_cost_peak_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
            state = "{{ ( states('sensor.electricity_cost_peak_kwh_energycomponent') | float ) + (1.44160 / 100) + (9.42 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
            state_class = "measurement";
          }
          {
            name = "electricity_cost_offpeak_kwh";
            unit_of_measurement = "€/kWh";
            # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
            state = "{{ ( states('sensor.electricity_cost_offpeak_kwh_energycomponent') | float ) + (1.44160 / 100) + (6.87 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
            state_class = "measurement";
          }
          {
            name = "energy/electricity/cost";
            unit_of_measurement = "€/kWh";
            state = ''
              {% if (states('binary_sensor.electricity_is_offpeak') | bool(false)) %}
                {{ states('sensor.electricity_cost_offpeak_kwh') | float }}
              {% else %}
                {{ states('sensor.electricity_cost_peak_kwh') | float }}
              {% endif %}
            '';
            state_class = "measurement";
          }
        ];
        binary_sensor = [
          {
            name = "energy/electricity/prefer_over_gas";
            state = ''
              {% set electricity_cost = states('sensor.energy_electricity_cost') | float(10) %}
              {% set gas_cost = states('sensor.gas_cost_kwh') | float(0.15) %}
              {{ (electricity_cost / 4) < gas_cost }}
            '';            
          }
          {
            name = "electricity_is_offpeak";
            state = ''
              {% set day = now().weekday() %}
              {% set hour = now().hour %}
              {% set is_weekend = day >= 5 %}
              {{ is_weekend or not(7 <= hour < 22) }}
            '';
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
            select = "table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(Dagtarief)";
            value_template = "{{ (value.split('€')[1]|replace(',', '.')|trim | float) / 100 }}";
            unit_of_measurement = "€/kWh";
            state_class = "measurement";
          }
          {
            name = "electricity_cost_offpeak_kwh_energycomponent";
            select = "table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(Nachttarief)";
            unit_of_measurement = "€/kWh";
            value_template = "{{ (value.split('€')[1]|replace(',', '.')|trim | float) / 100 }}";
            state_class = "measurement";
          }
          {
            name = "gas_cost_kwh_energycomponent";
            select = ''
              h3#octa-clear-gas + p + p + div table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(cent)
            '';
            unit_of_measurement = "€/kWh";
            value_template = ''
              {{ (value.split(':')[1].split('€')[1]|replace(',', '.')|trim | float) / 100 }}
            '';
            state_class = "measurement";
          }
        ];
      }
      {
        resource = "https://www.mijnenergie.be/blog/injectietarieven/";
        scan_interval = 3600;
        sensor = [
          {
            name = "electricity_injection_kwh";
            select = ''
              table :has(> td:-soup-contains(Octa)) td:nth-child(3)
            '' ;
            value_template = "{{ (value | replace(',', '.') | float(-1) / 100) | round(5) }}";
            unit_of_measurement = "€/kWh";
            state_class = "measurement";
          }
        ];
      }
      {
        resource = "https://www.pluginvest.eu/en/technische-hulp/creg-tarief/";
        scan_interval = 3600;
        sensor = [
          {
            name = "electricity_injection_creg_kwh";
            select = ''
              section.s_title h2 span.text-o-color-1 span
            '' ;
            value_template = ''{{ ((value | replace("€ ", "") | replace("/kWh", "") | replace(",", ".") | float) * 1.06) | round(3) }}'';
            unit_of_measurement = "€/kWh";
            state_class = "measurement";
          }
        ];
      }
    ];
  };
}
