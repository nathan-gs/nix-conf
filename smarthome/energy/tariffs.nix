{ config, pkgs, lib, ... }:
{

  services.home-assistant.config = {

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
        binary_sensor = [
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
            select = ''
              tr:nth-child(5):has(:-soup-contains("€cent/kWh")) td
            '';
            unit_of_measurement = "€/kWh";
            value_template = "{{ (value | replace(',', '.') | float) / 100 }}";
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
          }
        ];
      }
    ];
  };
}
