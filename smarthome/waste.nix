{ config, lib, pkgs, ... }:

{
  services.home-assistant.config = {
    afvalbeheer = {
      wastecollector = "RecycleApp";
      upcomingsensor = 1;
      printwastetypes = 0;
      postcode = config.secrets.address.zip;
      streetname = config.secrets.address.street;
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
        id = "waste_notify";
        alias = "waste.notify";
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
  };
}
