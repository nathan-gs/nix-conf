{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {
    afvalbeheer = {
      wastecollector = "RecycleApp";
      upcomingsensor = 1;
      printwastetypes = 0;
      postcode = config.secrets.address.zip;
      streetname = "Winkelwarande"; # nearby street as workaround for https://github.com/pippyn/Home-Assistant-Sensor-Afvalbeheer/issues/466
      streetnumber = config.secrets.address.streetNumber;
      dateformat = "%Y-%m-%d";
      resources = [
        "gft"
        "glas"
        "grofvuil"
        "papier"
        "pmd"
        "restafval"
      ];
    };

    "automation manual" = [
      {
        id = "system_waste_notify";
        alias = "system/waste.notify";
        trigger = [
          {
            platform = "time";
            at = "19:00:00";
          }
        ];
        condition = ''
          {% set upcoming_date = state_attr("sensor.recycleapp_first_upcoming", "Upcoming_day") | string %}
          {% set tomorrow = (now().date() + timedelta(days=1)) | string %}
          {{ upcoming_date == tomorrow }}
        '';
        action = [
          {
            service = "notify.notify";
            data = {
              title = "Vuilnisbakken";
              message = ''
                {% set waste_types = state_attr('sensor.recycleapp_first_upcoming', 'Upcoming_waste_types') %}
                Morgen vuilnisbakken: {{ waste_types }}
              '';
            };
          }
        ];
        mode = "single";
      }

    ];

    recorder = {
      exclude = {
        entities = [
          "calendar.afvalbeheer_recycleapp"
        ];
        entity_globs = [
          "sensor.recycleapp_*"
        ];
      };
    };
  };
}
