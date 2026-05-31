{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {
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

  };
}
