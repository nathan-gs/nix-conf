{ ha, ... }:
{

  imports = [
    ./car_charger
  ];

  services.home-assistant.config = {
    # Monthly and yearly utility meters for the Audi odometer (km).
    # Entity ids stay on the old Audi Connect name so existing history and
    # dashboard cards keep working. The source is the EU Data Act odometer,
    # which updates about every 15 minutes.
    utility_meter = 
      (ha.utility_meter "audi_a6_sportback_e_tron_mileage" "sensor.car_car_a6_mileage" "monthly")
      // 
      (ha.utility_meter "audi_a6_sportback_e_tron_mileage" "sensor.car_car_a6_mileage" "yearly");
  };

}