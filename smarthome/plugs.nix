let

  plugs = [     
    {
      zone = "garden";
      name = "laadpaal";
      ieee = "0x842e14fffe3b8777";
      floor = "garden";
    }    
    {
      zone = "living";
      name = "sonos_rear";
      ieee = "0x5c0272fffe88e39f";
      floor = "floor0";
    }
    {
      zone = "garden";
      name = "pomp";
      ieee = "0x9035eafffeb237bb";
      floor = "garden";
    }  
  ];

  metering_plugs = [
    {
      zone = "waskot";
      name = "droogkast";
      ieee = "0xa4c138163459950e";
      floor = "floor1";
    }
    {
      zone = "keuken";
      name = "oven";
      ieee = "0xa4c1381f8ccf7230";
      floor = "floor0";
    }
    {
      zone = "basement";
      name = "network";
      ieee = "0xa4c138ae189cf8bd";
      floor = "basement";
    }
    {
      zone = "waskot";
      name = "wasmachine";
      ieee = "0xa4c1383c42598ec3";
      floor = "floor1";
    }
    {
      zone = "fen";
      name = "deken";
      ieee = "0xa4c138bd0cf23138";
      floor = "floor1";
    }
    {
      zone = "badkamer";
      name = "verwarming";
      ieee = "0xa4c138fd75fc9f62";
      floor = "floor1";
    }
    {
      zone = "bureau";
      name = "verwarming";
      ieee = "0xa4c1388319da7258";
      floor = "floor0";
    }
    {
      zone = "living";
      name = "verwarming";
      ieee = "0xa4c138689a501455";
      floor = "floor0";
    }
  ];

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
    ++ map (v: v // { type = "plug";}) plugs
    ++ map (v: v // { type = "metering_plug";}) metering_plugs;
  
}