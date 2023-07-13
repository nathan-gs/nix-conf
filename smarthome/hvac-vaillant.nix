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
      # Quite an ugly regex workaround due to 0 not being findable...
      mode_state_template = ''
        {% set values = { 'auto':'auto', 'on':'heat',  'night':'cool', 'summer':'off'} %}
        {% set v = value | regex_findall_index( '"value"\s?:\s?"(.*)"')  %}
        {{ values[v] if v in values.keys() else 'auto' }}
      '';
      mode_state_topic = "ebusd/370/Hc1OPMode";
      mode_command_template = ''
        {% set values = { 'auto':'auto', 'heat':'on',  'cool':'night', 'off':'summer'} %}
        {{ values[value] if value in values.keys() else 'off' }}
      '';
      mode_command_topic = "ebusd/370/Hc1OPMode/set";
      temperature_state_topic = "ebusd/370/DisplayedHc1RoomTempDesired";
      temperature_state_template = "{{ value_json.temp1.value }}";
      temperature_low_state_topic = "ebusd/370/Hc1NightTemp";
      temperature_low_state_template = "{{ value_json.temp1.value }}";
      temperature_high_state_topic = "ebusd/370/Hc1DayTemp";
      temperature_high_state_template = "{{ value_json.temp1.value }}";
      temperature_low_command_topic = "ebusd/370/Hc1NightTemp/set";
      temperature_low_command_template = ''
        {{ value }}
      '';
      temperature_high_command_topic = "ebusd/370/Hc1DayTemp/set";
      temperature_high_command_template = ''
        {{ value }}
      '';
      current_temperature_topic = "ebusd/370/DisplayedRoomTemp";
      current_temperature_template = "{{ value_json.temp.value }}";
    }
  ];

  climate = [];

  recorder_excludes = [ ];
}
