{ config, lib, pkgs, ... }:

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
