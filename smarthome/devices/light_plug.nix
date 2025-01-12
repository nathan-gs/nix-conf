map
  (v: v // {
    type = "light_plug";
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
      zone = "keuken";
      name = "aanrecht";
      ieee = "0x0c4314fffee9dcd3";
      floor = "floor0";
    }
    {
      zone = "living";
      name = "kerstboom";
      ieee = "0x50325ffffe5ebbec";
      floor = "floor0";
      disabled = true;
    }
    {
      zone = "voordeur";
      name = "cirkel";
      ieee = "0xa4c138a92f204b18";
      floor = "garden";
      disabled = true;
    }
    

  ]
