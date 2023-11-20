let

  automations = [
    # Cirkel
    {
      id = "kerstverlichting_on";
      alias = "kerstverlichting_on";
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
        {
          service = "switch.turn_on";
          target.entity_id = "switch.floor0_living_light_plug_kerstboom";
        }
      ];
      mode = "single";
    }
    {
      id = "kerstverlichting_off";
      alias = "kerstverlichting_off";
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
        {
          service = "switch.turn_off";
          target.entity_id = "switch.floor0_living_light_plug_kerstboom";
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
          service = "light.turn_on";
          target.entity_id = "light.floor0_living_light_bollamp";
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
          service = "light.turn_off";
          target.entity_id = "light.floor0_living_light_bollamp";
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
          entity_id = ["input_boolean.floor0_bureau_in_use"];
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
          entity_id = ["input_boolean.floor0_bureau_in_use"];
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
          entity_id = ["input_boolean.floor0_bureau_in_use"];
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

in 
{

  automations = [] ++ automations;

}