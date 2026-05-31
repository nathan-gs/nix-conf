{ ha, ... }:
{

  imports = [
    ./car_charger
  ];

  services.home-assistant.config = {
    # Monthly and yearly utility meters for the Audi mileage sensor (km)
    utility_meter = 
      (ha.utility_meter "audi_a6_sportback_e_tron_mileage" "sensor.audi_a6_sportback_e_tron_mileage" "monthly")
      // 
      (ha.utility_meter "audi_a6_sportback_e_tron_mileage" "sensor.audi_a6_sportback_e_tron_mileage" "yearly");
  };

}