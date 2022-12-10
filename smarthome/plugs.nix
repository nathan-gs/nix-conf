{
  automations = [
    {
      id = "floor0_living_media_appletv_off switch floor1_fen_metering_plug_deken";
      alias = "floor0/living/media/appletv:off turn deken on";
      trigger = [
        {
          platform = "state";
          to = "off";        
          entity_id = "binary_sensor.floor0_living_appletv_woonkamer";
        }
      ];
      condition = [         
        {
          condition = "time";
          after = "22:00:00";
          before = "00:00:00";
        }
      ];
      action = [
        {
          service = "switch.turn_on";
          target.entity_id = "switch.floor1_fen_metering_plug_deken";
        }
        {
          delay = "0:20:00";
        }
        {
          service = "switch.turn_off";
          target.entity_id = "switch.floor1_fen_metering_plug_deken";
        }
      ];
      mode = "single";
    }
  ];
}