{config, pkgs, ...}:

{

  scrape = [];

  template = [
    
  ];
  sensor = [
  ];

  utility_meter = {};
  customize = {};

  automations = [   
  ];
  binary_sensor = [];


  # https://fromeijn.nl/connected-vaillant-to-home-assistant/
  mqtt.climate = [
    {
      name = "CV";
      max_temp = 25;
      min_temp = 10;
      precision = 0.1;
      temp_step = 0.5;
      modes = [ "auto" "heat" "cool" "off"];
      mode_state_template = ''
        {% set values = { 'auto':'auto', 'on':'heat',  'night':'cool', 'summer':'off'} %}
        {{ values[value] if value in values.keys() else 'off' }}
      '';
      mode_state_topic = "ebusd/370/Hc1OPMode";
      mode_command_template = ''
        {% set values = { 'auto':'auto', 'heat':'on',  'cool':'night', 'off':'summer'} %}
        {{ values[value] if value in values.keys() else 'auto' }}
      '';
      mode_command_topic = "ebusd/370/Hc1OPMode/set";
      temperature_state_topic = "ebusd/370/DisplayedHc1RoomTempDesired";
      temperature_low_state_topic = "ebusd/370/Hc1NightTemp";
      temperature_high_state_topic = "ebusd/370/Hc1DayTemp";
      temperature_low_command_topic = "ebusd/370/Hc1NightTemp/set";
      temperature_high_command_topic = "ebusd/370/Hc1DayTemp/set";
      current_temperature_topic = "ebusd/370/DisplayedRoomTemp";
    }
  ];

  climate = [];

  recorder_excludes = [ ];
}
