{ ha, ... }:
{

  imports = [
    ./audi-a6.nix
    ./car_charger
  ];

  services.home-assistant.config = {
    # Monthly and yearly utility meters for the Audi odometer (km).
    # Entity ids stay on the old Audi Connect name so existing history and
    # dashboard cards keep working. The source is the car/audi-a6/mileage
    # template (audi-a6.nix), which takes the higher of the Audi Connect and
    # EU Data Act odometers so the meter never sees a drop.
    utility_meter =
      (ha.utility_meter "audi_a6_sportback_e_tron_mileage" "sensor.car_audi_a6_mileage" "monthly")
      //
      (ha.utility_meter "audi_a6_sportback_e_tron_mileage" "sensor.car_audi_a6_mileage" "yearly");
  };

}
