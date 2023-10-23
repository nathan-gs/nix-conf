{ config, pkgs, lib, ... }:

let

  # https://www.irceline.be/tables/no2/no2.php?lan=en
  # table :has(> td:contains(44R731)) td[align=center] 
  # 2 vars

  # https://www.irceline.be/tables/pm/pm10.php?lan=en
  # https://www.irceline.be/tables/ozone/ozone.php?lan=en
  # https://www.irceline.be/tables/index/subindex_air_belaqi.php?lan=nl

  locations = [
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
        sensor = [
          {
            name = "irceline_air_quality_no2_sxw_current";
            select = ''
              table :has(> td:-soup-contains("44R740")) td[align=center] > :first-child :first-child
            '' ;
            value_template = "{{ value | int(-1) }}";
            unit_of_measurement = "µg/m³";
            device_class = "nitrogen_dioxide";
          }
          {
            name = "irceline_air_quality_no2_sxw_24h";
            select = ''
              table :has(> td:-soup-contains("44R740")) td:nth-child(5)
            '' ;
            value_template = "{{ (value) }}";
            unit_of_measurement = "µg/m³";
            device_class = "nitrogen_dioxide";
          }
        ];
      }
      {
        resource = "https://www.irceline.be/tables/ozone/ozone.php?lan=en";
        scan_interval = 3600;
        sensor = [
          {
            name = "irceline_air_quality_ozone_sxw_current";
            select = ''
              table :has(> td:-soup-contains("44R740")) td:nth-child(4)
            '' ;
            value_template = "{{ value | int(-1) }}";
            unit_of_measurement = "µg/m³";
            device_class = "ozone";
          }
        ];
      }
    ];
  };
}
