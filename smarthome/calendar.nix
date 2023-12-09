{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [
          {
            name = "workday";
            state = "{{ (now().weekday() < 5) }}";
          }
        ];
      }
    ];
  };
}
