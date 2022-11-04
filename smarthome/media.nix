{
  automations = [
    {
      id = "floor0_living_media_appletv:on";
      alias = "floor0/living/media/appletv:on";
      trigger = [
        {
          platform = "state";
          to = "on";        
          entity_id = "binary_sensor.floor0_living_appletv_woonkamer";        
        }
      ];
      condition = [];
      action = [
        {
          service = "switch.turn_on";
          data = {};
          target.entity_id = "switch.floor0_living_plug_sonos_rear";
        }
      ];
      mode = "single";
    }
    {
      id = "floor0_living_media_appletv:off";
      alias = "floor0/living/media/appletv:off";
      trigger = [
        {
          platform = "state";
          to = "off";        
          entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
        }
      ];
      condition = [];
      action = [
        {
          service = "switch.turn_off";
          data = {};
          target.entity_id = "switch.floor0_living_plug_sonos_rear";
        }
      ];
      mode = "single";
    }
  ];
}