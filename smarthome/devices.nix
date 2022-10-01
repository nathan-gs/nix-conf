{ config, lib, pkgs, ... }:
let
  rtv = [
    {      
      zone = "living";
      name = "vooraan";
      ieee = "0x0c4314fffe639db0";
      floor = "floor0";
    }
    {      
      zone = "living";
      name = "achteraan";
      ieee = "0x0c4314fffe73c3ab";
      floor = "floor0";
    }
    {
      zone = "bureau";
      name = "na";
      ieee = "0x0c4314fffe62fd84";
      floor = "floor0";
    }
    {
      zone = "keuken";
      name = "na";
      ieee = "0x0c4314fffe63c110";
      floor = "floor0";
    }
    {
      zone = "morgane";
      name = "na";
      ieee = "0x0c4314fffe73c020";
      floor = "floor1";
    }
    {
      zone = "nikolai";
      name = "na";
      ieee = "0x0c4314fffe6188ea";
      floor = "floor1";
    }
    {
      zone = "fen";
      name = "na";
      ieee = "0x0c4314fffe62df15";
      floor = "floor1";
    }
    {
      zone = "badkamer";
      name = "na";
      ieee = "0x0c4314fffe62e681";
      floor = "floor1";
    }
  ];
  windows = [
    {
      zone = "morgane";
      name = "na";
      ieee = "0x847127fffead504a";
      floor = "floor1";
    }
    {
      zone = "nikolai";
      name = "na";
      ieee = "0x847127fffed3d47e";
      floor = "floor1";
    }
    {
      zone = "fen";
      name = "na";
      ieee = "0xa4c1382fd78a278a";
      floor = "floor1";
    }
    {
      zone = "badkamer";
      name = "na";
      ieee = "0x847127fffeaf3190";
      floor = "floor1";
    }
  ];

  plugs = [
    {
      zone = "roaming";
      name = "meter0";
      ieee = "0xa4c138163459950e";
      floor = "roaming";
    }
    {
      zone = "living";
      name = "kattenlamp";
      ieee = "0x0c4314fffee9dcd3";
      floor = "floor0";
    }
    {
      zone = "living";
      name = "bollamp";
      ieee = "0x50325ffffe5ebbec";
      floor = "floor0";
    }
    {
      zone = "garden";
      name = "laadpaal";
      ieee = "0x842e14fffe3b8777";
      floor = "garden";
    }
  ];

  zigbeeDevices = 
    map (v: v // { type = "rtv";}) rtv 
    ++ map (v: v //  { type = "window";}) windows 
    ++ map (v: v // { type = "plug";}) plugs;

  zigbeeDevicesWithIeeeAsKey = 
    map (v: { name = "${v.ieee}"; value = { friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";};}) zigbeeDevices;

  zigbeeDevicesAsAttr = builtins.listToAttrs zigbeeDevicesWithIeeeAsKey;
in 

with lib;
{
  services.zigbee2mqtt.settings.devices = zigbeeDevicesAsAttr;
}
