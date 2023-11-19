map
  (v: v // {
    type = "light_plug";
    # https://www.zigbee2mqtt.io/guide/usage/integrations/home_assistant.html#exposing-switch-as-a-light
    homeassistant = {
      switch = {
        name = "${v.floor}/${v.zone}/light_plug/${v.name}";
        type = "light";
        object_id = "";
      };
      light = {
        name = "${v.floor}/${v.zone}/light_plug/${v.name}";
        value_template = ''{{ value_json.state }}'';
        state_value_template = ''{{ value_json.state }}'';
      };
      icon = "mdi:lamp";
    };
  })
  [
    {
      zone = "living";
      name = "kattenlamp";
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

  ]
