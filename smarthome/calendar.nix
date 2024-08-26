{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [
          {
            name = "workday";
            state = ''
              {% set not_holiday_at_home = states('input_boolean.holiday_at_home') | bool(false) == false %}
              {% set workday = (now().weekday() < 5) %}
              {{ not_holiday_at_home and workday }}
            '';
          }
        ];
      }
    ];
    
    input_boolean = {
      holiday_at_home = {
        name = "holiday at home";
        icon = "mdi:fireplace";
      };
    };

    recorder = {
      include = {
        entities = [
          "binary_sensor.workday"
          "input_boolean.holiday_at_home"          
        ];

        entity_globs = [
        ];
      };
    };
  };

}
