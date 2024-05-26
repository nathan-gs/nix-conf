{ config, pkgs, lib, ha, ... }:

let

  # https://www.irceline.be/tables/no2/no2.php?lan=en
  # table :has(> td:contains(44R731)) td[align=center] 
  # 2 vars

  # https://www.irceline.be/tables/pm/pm10.php?lan=en
  # https://www.irceline.be/tables/ozone/ozone.php?lan=en
  # https://www.irceline.be/tables/index/subindex_air_belaqi.php?lan=nl

  locations_pm10 = [
    {
      station = "44R740";
      name = "sxw";
    }
    {
      station = "44R731";
      name = "evergem";
    }
    {
      station = "40EG05";
      name = "rieme";
    }
    {
      station = "44R750";
      name = "zelzate";
    }

  ];

  locations_ozone = [
    {
      station = "44R740";
      name = "sxw";
    }
  ];

  locations_no2 = [
    {
      station = "44R740";
      name = "sxw";
    }
    {
      station = "44R731";
      name = "evergem";
    }
    {
      station = "47E704";
      name = "wachtebeke";
    }
    {
      station = "44R750";
      name = "zelzate";
    }
  ];

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

    scrape = [
      {
        resource = "https://www.irceline.be/tables/no2/no2.php?lan=en";
        scan_interval = 3600;
        sensor = 
          map (l: 
            sensor "irceline/${l.name}/air_quality/no2" ''table :has(> td:-soup-contains("${l.station}")) td[align=center] > :first-child :first-child'' "nitrogen_dioxide"
          ) locations_no2 
          ++
          map (l: 
            sensor "irceline/${l.name}/air_quality/no2/24h" ''table :has(> td:-soup-contains("${l.station}")) td:nth-child(5)'' "nitrogen_dioxide"
          ) locations_no2;
      }
      {
        resource = "https://www.irceline.be/tables/ozone/ozone.php?lan=en";
        scan_interval = 3600;
        sensor = map (l: 
          sensor "irceline/${l.name}/air_quality/ozone" ''table :has(> td:-soup-contains("${l.station}")) td:nth-child(4)'' "ozone"
        ) locations_ozone;
      }
      {
        resource = "https://www.irceline.be/tables/pm/pm10.php?lan=en";
        scan_interval = 3600;
        sensor = 
          map (l: 
            sensor "irceline/${l.name}/air_quality/pm10" ''table :has(> td:-soup-contains("${l.station}")) td:nth-child(4)'' "pm10"
          ) locations_pm10 
          ++
          map (l: 
            sensor "irceline/${l.name}/air_quality/pm25" ''table :has(> td:-soup-contains("${l.station}")) td:nth-child(7)'' "pm25"        
          ) locations_pm10;
      }
    ];
  };
}
