let

  plugs = import ./devices/plugs.nix;
  metering_plugs = import ./devices/metering_plugs.nix;

in 
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
      ];
      mode = "single";
    }
    {
      id = "floor1_fen_metering_plug_deken_on_auto_off";
      alias = "floor1/fen/metering_plug_deken on -> auto off";
      trigger = [
        {
          platform = "state";
          to = "on";        
          entity_id = "switch.floor1_fen_metering_plug_deken";
        }
      ];
      action = [
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

  devices = []
    ++ map (v: v // { 
        type = "plug";
        home_assistant.child_lock = null;
      }) plugs
    ++ map (v: v // { 
      type = "metering_plug";
      home_assistant.child_lock = null;
    }) metering_plugs;
  
}