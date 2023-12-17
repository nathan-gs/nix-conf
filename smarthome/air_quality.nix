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


in
{

  services.home-assistant.config = {

    scrape = [
      {
        resource = "https://www.irceline.be/tables/no2/no2.php?lan=en";
        scan_interval = 3600;
        sensor = 
        map (l: 
          {
            name = "irceline/${l.name}/air_quality/no2";
            select = ''
              table :has(> td:-soup-contains("${l.station}")) td[align=center] > :first-child :first-child
            '';
            value_template = "{{ value | float(-1) }}";
            unit_of_measurement = "µg/m³";
            device_class = "nitrogen_dioxide";
          }) locations_no2 ++
        map (l: {
            name = "irceline/${l.name}/air_quality/no2/24h";
            select = ''
              table :has(> td:-soup-contains("${l.station}")) td:nth-child(5)
            '';
            value_template = "{{ (value | float(-1))  }}";
            unit_of_measurement = "µg/m³";
            device_class = "nitrogen_dioxide";
          }) locations_no2;
      }
      {
        resource = "https://www.irceline.be/tables/ozone/ozone.php?lan=en";
        scan_interval = 3600;
        sensor = map (l: (
          {
            name = "irceline/${l.name}/air_quality/ozone";
            select = ''
              table :has(> td:-soup-contains("${l.station}")) td:nth-child(4)
            '';
            value_template = "{{ value | float(-1) }}";
            unit_of_measurement = "µg/m³";
            device_class = "ozone";
          }
          )) locations_ozone;
      }
      {
        resource = "https://www.irceline.be/tables/pm/pm10.php?lan=en";
        scan_interval = 3600;
        sensor = 
        map (l: 
          {
            name = "irceline/${l.name}/air_quality/pm10";
            select = ''
              table :has(> td:-soup-contains("${l.station}")) td:nth-child(4)
            '';
            value_template = "{{ value | float(-1) }}";
            unit_of_measurement = "µg/m³";
            device_class = "pm10";
          }) locations_pm10 ++
        map (l: 
          {
            name = "irceline/${l.name}/air_quality/pm25";
            select = ''
              table :has(> td:-soup-contains("${l.station}")) td:nth-child(7)
            '';
            value_template = "{{ (value | float(-1))  }}";
            unit_of_measurement = "µg/m³";
            device_class = "pm25";
          }
          ) locations_pm10;
      }
    ];
  };
}
