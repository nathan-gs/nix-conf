map
  (v: v // {
    type = "light_switch";
    # https://www.zigbee2mqtt.io/guide/usage/integrations/home_assistant.html#exposing-switch-as-a-light
    homeassistant = {
      switch = {
        type = "light";
        object_id = "l1";
      };
      "l1" = {
        object_id = null;
        value_template = null;
        state_value_template = ''{{ value_json.state }}'';
      };
    };
  })
  [
    {
      zone = "living";
      name = "raam_zuid";
      ieee = "0x287681fffe7146ad";
      floor = "floor0";
    }
    {
      zone = "wc";
      name = "main";
      ieee = "0xe0798dfffea7b7e2";
      floor = "floor0";
    }
    {
      zone = "badkamer";
      name = "spiegel";
      ieee = "0xe0798dfffea7bc20";
      floor = "floor1";
    }
  ]
++
map
  (v: v // {
    type = "light_switch";
    # https://www.zigbee2mqtt.io/guide/usage/integrations/home_assistant.html#exposing-switch-as-a-light
    homeassistant = {
      switch_l1 = {
        type = "light";
        object_id = "l1";
      };
      switch_l2 = {
        type = "light";
        object_id = "l2";
      };
      "l1" = {
        name = null;
        value_template = null;
        state_value_template = ''{{ value_json.state_l1 }}'';
      };
      "l2" = {
        name = null;
        value_template = null;
        state_value_template = ''{{ value_json.state_l2 }}'';
      };
      #icon = "mdi:lamp";
    };
  })
  [    
    {
      zone = "keuken";
      name = "main";
      ieee = "0x30fb10fffe339081";
      floor = "floor0";
    }        
    {
      zone = "badkamer";
      name = "main";
      ieee = "0x30fb10fffe47f573";
      floor = "floor1";
    }
    
  ]