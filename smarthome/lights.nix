let
  lights = [
    {      
      zone = "bureau";
      name = "desk";
      ieee = "0x842e14fffe674147";
      floor = "floor0";
    }
    {      
      zone = "roaming";
      name = "closet";
      ieee = "0x50325ffffeaca4be";
      floor = "roaming";
    }
    {      
      zone = "bureau";
      name = "desk2";
      ieee = "0x0c4314fffe98c59f";
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
    {
      zone = "voordeur";
      name = "cirkel";
      ieee = "0xa4c138fd75fc9f62";
      floor = "garden";
    }
  ];

  automations = [
    # Cirkel
    {
      id = "garden_voordeur_cirkel_on";
      alias = "garden_voordeur_cirkel_on";
      trigger = [
        {
          platform = "sun";
          event = "sunset";
          offset = "-00:30:00";          
        }
        {
          platform = "time";
          at = "07:00:00";    
        } 
      ];
      action = [
        {
          service = "switch.turn_on";
          target.entity_id = "switch.garden_voordeur_light_plug_cirkel";	        
        }
      ];
      mode = "single";
    }
    {
      id = "garden_voordeur_cirkel_off";
      alias = "garden_voordeur_cirkel_off";
      trigger = [
        {
          platform = "time";
          at = "23:00:00";    
        }              
        {
          platform = "sun";
          event = "sunrise";
          offset = "00:30:00";          
        } 
      ];
      action = [
        {
          service = "switch.turn_off";
          target.entity_id = "switch.garden_voordeur_light_plug_cirkel";
        }
      ];
      mode = "single";
    }
    # Living
    {
      id = "floor0_living_lights_on";
      alias = "floor0_living_lights_on";
      trigger = [
        {
          platform = "sun";
          event = "sunset";
          offset = "-00:30:00";          
        }
      ];
      action = [
        {
          service = "switch.turn_on";
          target.entity_id = "switch.floor0_living_light_plug_kattenlamp";
        }
        {
          service = "switch.turn_on";
          target.entity_id = "switch.floor0_living_light_plug_bollamp";
        }
      ];
      mode = "single";
    }
    {
      id = "floor0_living_lights_off";
      alias = "floor0_living_lights_off";
      trigger = [
        {
          platform = "time";
          at = "23:00:00";    
        }
      ];
      action = [
        {
          service = "switch.turn_off";
          target.entity_id = "switch.floor0_living_light_plug_kattenlamp";
        }
        {
          service = "switch.turn_off";
          target.entity_id = "switch.floor0_living_light_plug_bollamp";
        }
      ];
      mode = "single";
    }
    # NDESK Light
    {
      id = "floor0_bureau_lights_on_before_sunrise";
      alias = "floor0_bureau_lights_on_before_sunrise";
      trigger = [
        {
          platform = "state";
          entity_id = ["binary_sensor.ndesk"];
          to = "on";
        }
      ];
      condition = [
        {
          condition = "sun";
          before = "sunrise";
        }
      ];
      action = [
        {
          service = "light.turn_on";
          target.entity_id = "light.floor0_bureau_light_desk";
        }
      ];
      mode = "single";
    }
    {
      id = "floor0_bureau_lights_on_at_sunset";
      alias = "floor0_bureau_lights_on_at_sunset";
      trigger = [
        {
          platform = "sun";
          event = "sunset";
          offset = "-00:30:00";          
        }
      ];
      condition = [
        {
          condition = "state";
          entity_id = ["binary_sensor.ndesk"];
          state = "on";
        }
      ];
      action = [
        {
          service = "light.turn_on";
          target.entity_id = "light.floor0_bureau_light_desk";
        }
      ];
      mode = "single";
    }
    {
      id = "floor0_bureau_lights_off";
      alias = "floor0_bureau_lights_off";
      trigger = [
        {
          platform = "sun";
          event = "sunrise";
          offset = "00:30:00";          
        } 
        {
          platform = "state";
          entity_id = ["binary_sensor.ndesk"];
          to = "off";
        }
      ];
      condition = [];
      action = [
        {
          service = "light.turn_off";
          target.entity_id = "light.floor0_bureau_light_desk";
        }
      ];
      mode = "single";
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
  devices = [] ++ map (v: v // {type = "light";}) lights;
  zigbeeDevices = {} // lightPlugDevices;
  automations = [] ++ automations;

}