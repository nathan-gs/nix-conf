{
  template = [  
    {
      sensor = [
        {
          name = "energy_gas_cost_kwh";
          unit_of_measurement = "€/kWh";
          # Cost = vendor + federal tax + federal accijns + nettarifs + transport
          state = "{{ ( states('sensor.energy_gas_cost_kwh_energycomponent') | float ) + (0.1058 / 100) + (0.0572 / 100) + (2.07 / 100) + (1.41 / 1000) }}";
        }
        {
          name = "energy_gas_cost_m3";
          unit_of_measurement = "€/m³";
          state = "{{ ( states('sensor.energy_gas_cost_kwh') | float ) * 11.60}}";
        }            
        {
          name = "energy_electricity_cost_peak_kwh";
          unit_of_measurement = "€/kWh";
          # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
          state = "{{ ( states('sensor.energy_electricity_cost_peak_kwh_energycomponent') | float ) + (1.44160 / 100) + (9.42 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
        }
        {
          name = "energy_electricity_cost_offpeak_kwh";
          unit_of_measurement = "€/kWh";
          # Cost = vendor + federal accijns + nettarifs + transport + bijdrage energie + groene stroom + wkk
          state = "{{ ( states('sensor.energy_electricity_cost_offpeak_kwh_energycomponent') | float ) + (1.44160 / 100) + (6.87 / 100) + (1.26 / 100) + (0.2942 / 100) + (2.233 / 100) + (0.344 / 100) }}";      
        }
      ];
    }
  ];

  sensor = [
    {
      platform = "scrape";
      resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
      name = "energy_electricity_cost_peak_kwh_energycomponent";
      select = "table :has(> th:contains(Dagtarief)) td";
      unit_of_measurement = "€/kWh";
      value_template = "{{ (value | float) / 100 }}";
      scan_interval = 3600;
    }
    {
      platform = "scrape";
      resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
      name = "energy_electricity_cost_offpeak_kwh_energycomponent";
      select = "table :has(> th:contains(Nachttarief)) td";
      unit_of_measurement = "€/kWh";
      value_template = "{{ (value | float) / 100 }}";
      scan_interval = 3600;
    }
    {
      platform = "scrape";
      resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
      name = "energy_gas_cost_kwh_energycomponent";
      select = "table :has(> th:contains(per)) td";
      unit_of_measurement = "€/kWh";
      value_template = "{{ (value | float) / 100 }}";
      scan_interval = 3600;
    }      
  ];
}