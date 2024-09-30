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
            state = ''
              {% set energycomponent = states('sensor.gas_cost_engie_drive_kwh_energycomponent') | float %}
              {% set gas_yearly = (states('sensor.gas_delivery_yearly') | float * 11.5822997166)  %}
              {% set imewo = (0.887 / 100) %}
              {% if gas_yearly < 5000 %}
                {% set imewo = (2.454 / 100) %}
              {% endif %}
              {% set transport = (0.162 / 100) %}
              {% set energiebijdrage = (0.10577 / 100) %}
              {% set accijns = (0.97549 / 100) %}
              {% if gas_yearly < 12000 %}
                {% set accijns = (0.87238 / 100) %}
              {% endif %}
              {{ (energycomponent + imewo + transport + energiebijdrage + accijns) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            name = "gas_cost_m3";
            unit_of_measurement = "€/m³";
            state = "{{ ( states('sensor.gas_cost_kwh') | float ) * 11.5822997166}}";
            state_class = "measurement";
          }
          {
            name = "gas_cost_monthly_fixed";
            unit_of_measurement = "€";
            state = ''
              {% set gas_yearly = (states('sensor.gas_delivery_yearly') | float * 11.5822997166)  %}
              {% set engie = 37.1 %}
              {% set discount = 0 %}
              {% if now().year < 2025 and now().month < 10 %}
                {% set discount = 37.1 %}
              {% endif %}
              {% set imewo = 95.37 %}
              {% if gas_yearly < 5000 %}
                {% set imewo = 17.0 %}
              {% endif %}
              {% set databeheer = 13.95 %}
              {{ ((engie / 12) - (discount / 12) + (imewo / 12) + (databeheer / 12)) | round(5) }}
            '';
          }           
          {
            name = "electricity_cost_peak_kwh";
            unit_of_measurement = "€/kWh";
            state = ''
              {% set energycomponent = states('sensor.electricity_cost_engie_drive_peak_kwh_energycomponent') | float %}
              {% set wkk_and_greenenergy = (1.582 / 100) %}
              {% set imewo = (4.71756 / 100) %}
              {% set energiebijdrage = (0.20417 / 100) %}
              {% set accijns = (5.03288 / 100) %}
              {{ (energycomponent + wkk_and_greenenergy + imewo + energiebijdrage + accijns) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            name = "electricity_cost_offpeak_kwh";
            unit_of_measurement = "€/kWh";            
            state = ''
              {% set energycomponent = states('sensor.electricity_cost_engie_drive_offpeak_kwh_energycomponent') | float %}
              {% set wkk_and_greenenergy = (1.582 / 100) %}
              {% set imewo = (4.71756 / 100) %}
              {% set energiebijdrage = (0.20417 / 100) %}
              {% set accijns = (5.03288 / 100) %}
              {{ (energycomponent + wkk_and_greenenergy + imewo + energiebijdrage + accijns) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            name = "electricity_cost_monthly_fixed";
            unit_of_measurement = "€";
            state = ''
              {% set engie = 100.7 %}
              {% set imewo_capacitytariffs_per_kw = 41.7713 %}
              {# Not 100% correct, 1 peak influences full month #}
              {% set capacity_peak_current_month = max(states('sensor.electricity_delivery_power_monthly_15m_max') | float(2.5), 2.5) %}
              {% set discount = 0 %}
              {% if now().year < 2025 and now().month < 10 %}
                {% set discount = 80.0 %}
              {% endif %}
              {% set databeheer = 13.95 %}
              {{ ((engie / 12) + ((imewo_capacitytariffs_per_kw / 12 ) * capacity_peak_current_month) - (discount / 12) + (databeheer / 12)) | round(5) }}
            '';
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
            name = "electricity_cost_octa_peak_kwh_energycomponent";
            select = "table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(Dagtarief)";
            value_template = "{{ (value.split('€')[1]|replace(',', '.')|trim | float) / 100 }}";
            unit_of_measurement = "€/kWh";
            state_class = "measurement";
          }
          {
            name = "electricity_cost_octa_offpeak_kwh_energycomponent";
            select = "table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(Nachttarief)";
            unit_of_measurement = "€/kWh";
            value_template = "{{ (value.split('€')[1]|replace(',', '.')|trim | float) / 100 }}";
            state_class = "measurement";
          }
          {
            name = "gas_cost_octa_kwh_energycomponent";
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
        resource = "https://callmepower.be/nl/energie/leveranciers/engie-electrabel/tarieven/drive";
        scan_interval = 3600;
        sensor = [
          {
            name = "electricity_cost_engie_drive_peak_kwh_energycomponent";
            # TODO Sept 2025 replace the discount
            select = ''
              h2#actuele-engie-drive-prijzen-per-kwh + p + p + div table tbody td li:-soup-contains(Dagtarief)
            '';
            value_template = ''
              {% set discount = 0 %}
              {% if now().year < 2025 and now().month < 10 %}
                {% set discount = 0.0293 %}
              {% endif %}
              {{ (((value.split('€')[1]|replace(',', '.')|trim | float) / 100) - discount) | round(5) }}
            '';
            unit_of_measurement = "€/kWh";
            state_class = "measurement";
          }
          {
            name = "electricity_cost_engie_drive_offpeak_kwh_energycomponent";
            # TODO Sept 2025 replace the discount
            select = ''
              h2#actuele-engie-drive-prijzen-per-kwh + p + p + div table tbody td li:-soup-contains(Nachttarief)
            '';
            unit_of_measurement = "€/kWh";
            value_template = 
            ''
              {% set discount = 0 %}
              {% if now().year < 2025 and now().month < 10 %}
                {% set discount = 0.0293 %}
              {% endif %}
              {{ (((value.split('€')[1]|replace(',', '.')|trim | float) / 100) - discount) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            name = "gas_cost_engie_drive_kwh_energycomponent";
            select = ''
              h3#gasprijs-engie-drive + p + p + div table:has(th:-soup-contains(Drive)) tbody td li:-soup-contains(cent)
            '';
            unit_of_measurement = "€/kWh";
            # TODO Sept 2025 replace the discount
            value_template = ''
              {% set discount = 0 %}
              {% if now().year < 2025 and now().month < 10 %}
                {% set discount = 0.0106 %}
              {% endif %}
              {{ (((value.split(':')[1].split('€')[1]|replace(',', '.')|trim | float) / 100) - discount) | round(5) }}
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
          {
            name = "electricity_injection_engie_drive_peak_kwh";
            select = ''
              table :has(> td:-soup-contains(Flow)) td:nth-child(4)
            '' ;
            value_template = "{{ (value | replace(',', '.') | float(-1) / 100) | round(5) }}";
            unit_of_measurement = "€/kWh";
            state_class = "measurement";
          }
          {
            name = "electricity_injection_engie_drive_offpeak_kwh";
            select = ''
              table :has(> td:-soup-contains(Flow)) td:nth-child(5)
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
            value_template = ''{{ ((value | replace("€ ", "") | replace("/kWh", "") | replace(",", ".") | float) * 1) | round(3) }}'';
            unit_of_measurement = "€/kWh";
            state_class = "measurement";
          }
        ];
      }
    ];
  };
}
