let
  lights = [
    {      
      zone = "bureau";
      name = "desk";
      ieee = "0x842e14fffe674147";
      floor = "floor0";
    }
  ];

  lightPlugs = [
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
  ];

  lightPlugDevices = 
    builtins.listToAttrs ( 
      (
        map (v: { name = "${v.ieee}"; value = { 
        friendly_name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
        homeassistant = {
#          name = "${v.zone} Light ${v.name}";
#          switch = {
#            type = "light";
#            object_id = "light";            
#          };
#          light = {
#            name = "${v.floor}/${v.zone}/${v.type}/${v.name}";
#            value_template = "";
#            state_value_template = "'{{ value_json.state }}'";
#          };
        };
      };})
      )
      (
        map (v: v // { type = "light_plug";}) lightPlugs
      )
    );
in 
{
  devices = lights;
  zigbeeDevices = [] ++ lightPlugDevices;
  automations = [];

}