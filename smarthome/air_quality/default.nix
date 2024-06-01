{ config, pkgs, lib, ha, ... }:

let

  # https://www.irceline.be/tables/no2/no2.php?lan=en
  # table :has(> td:contains(44R731)) td[align=center] 
  # 2 vars

  # https://www.irceline.be/tables/pm/pm10.php?lan=en
  # https://www.irceline.be/tables/ozone/ozone.php?lan=en
  # https://www.irceline.be/tables/index/subindex_air_belaqi.php?lan=nl


  sensor = name: select: device_class: 
    {
      name = name;
      select = select;
      value_template = ''{{ value | float("unavailable") }}'';
      unit_of_measurement = "µg/m³";
      device_class = device_class;
      state_class = "measurement";
    };

in
{

  services.home-assistant.config = {

    # Replaced by sos2mqtt
    sensor = [];
    template = [
      
    ];

    recorder.exclude = {
      entity_globs = [
      
      ];
    };
  };

}
