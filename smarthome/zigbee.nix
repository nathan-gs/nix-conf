{ config, lib, pkgs, ... }:

let

  devices = import ./devices;
  
  zigbeeDevices = {} //
    builtins.listToAttrs ( 
      (
        map (v: { name = "${v.ieee}"; value = v // { 
          friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
          homeassistant = v.homeassistant // {
            update = null;
            expire_after = 3600;
            object_id = "${v.floor}_${v.zone}_${v.type}_${v.name}";
            device.suggested_area = "${v.floor}/${v.zone}";
          };
        };})
      )
      devices
    );
in
{
  services.zigbee2mqtt.settings = {
    devices = zigbeeDevices;
    external_converters = [
    ];
    availability = true;
  };

}