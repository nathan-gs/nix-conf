{ config, pkgs, lib, ... }:

let

  autoWantedHeader = ''
    {% set workday = states('binary_sensor.workday') | bool(true) %}    
    {% set anyone_home = states('binary_sensor.anyone_home') | bool(true) %}
    {% set temperature_away = 14.5 %}
    {% set temperature_eco = 15.5 %}
    {% set temperature_night = 16.5 %}
    {% set temperature_comfort_low = 17 %}
    {% set temperature_comfort = 18.5 %}
    {% set temperature_minimal = 5.5 %}
  '';

  rtv = import ./hvac/devices/rtv.nix;
  windows = import ./hvac/devices/windows.nix;
  tempSensors = import ./hvac/devices/temperature.nix;
  rtvFilteredAttributes = import ./hvac/devices/rtvFilteredAttributes.nix;

  rtvDevices = builtins.listToAttrs (
    (
      map (v: {
        name = "${v.ieee}";
        value = {
          friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
          homeassistant = { } // builtins.listToAttrs (map (vf: { name = vf; value = null; }) rtvFilteredAttributes);
          filtered_attributes = rtvFilteredAttributes;
          optimistic = false;
          availability = true;
        };
      })
    )
      (
        map (v: v // { type = "rtv"; }) rtv
      )
  );

  temperatureRtvAutomations =
    [];

  temperatureCalibrationAutomations =
    [];

  temperatureAutoWanted = [
    {
      sensor = [
        
      ];
    }
  ];

  roomTemperatureDifferenceWanted = map
    (v:
      {
        name = "${v.floor}_${v.zone}_rtv_${v.name}_temperature_diff_wanted";
        unit_of_measurement = "°C";
        device_class = "temperature";
        state = ''
          {% set temperature_wanted = state_attr("climate.${v.floor}_${v.zone}_rtv_${v.name}", "temperature") | float(15.5) %}
          {% set temperature_actual = states("sensor.${v.floor}_${v.zone}_temperature") | float(15.5) %}
          {{ (temperature_wanted - temperature_actual) | round(2) }}
        '';
        icon = "mdi:thermometer-auto";
      })
    rtv;

  heatingNeededRtvSensors = map (v: "states('sensor.${v.floor}_${v.zone}_rtv_${v.name}_temperature_diff_wanted')") rtv;

  heatingNeeded = [
    
    

  ];

in
{
  devices = [ ]
    ++ map (v: v // { type = "window"; }) windows
    ++ map (v: v // { type = "temperature"; }) tempSensors;
  zigbeeDevices = { } // rtvDevices;
  automations = [ ]
    ++ temperatureRtvAutomations
    ++ temperatureCalibrationAutomations;

  template = [ ]
    ++ temperatureAutoWanted
    ++ [{ sensor = roomTemperatureDifferenceWanted; }]
    ++ [{ sensor = heatingNeeded; }];  


  recorder_excludes = [
    "binary_sensor.*_window_*_tamper"
    "binary_sensor.*_rtv_*_away_mode"
  ];
}
