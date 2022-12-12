{

  automations = [
    {
      id = "ndesk_on_turn_on_heating_in_bureau";
      alias = "ndesk:on turn on heating in bureau";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.ndesk";
          to = "on";
        }
      ];
      condition = [];
      action = [
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data = {
            temperature = "{{ states('input_number.temperature_comfort') | float }}";
          };
        }
      ];
      mode = "single";
    }
    {
      id = "flaptop_on_turn_on_heating_in_nikolai";
      alias = "flaptop:on turn on heating in Nikolaï's room";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.flaptop";
          to = "on";
        }
      ];
      condition = [];
      action = [
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_nikolai_rtv_na";
          data = {
            temperature = "{{ states('input_number.temperature_comfort') | float }}";
          };
        }
      ];
      mode = "single";
    }
    {
      id = "ndesk_off_heating_auto_in_bureau";
      alias = "ndesk:off heating auto in bureau";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.ndesk";
          to = "off";
        }
      ];
      condition = [];
      action = [
        {
          service = "input_boolean.turn_on";
          data.entity_id = "input_boolean.floor0_bureau_rtv_is_auto";
        }
      ];
      mode = "single";
    }
    {
      id = "flaptop_off_heating_auto_in_nikolai";
      alias = "flaptop:off heating auto in nikolai's room";
      trigger = [
        {
          platform = "state";
          entity_id = "binary_sensor.flaptop";
          to = "off";
        }
      ];
      condition = [];
      action = [
        {
          service = "input_boolean.turn_on";
          data.entity_id = "input_boolean.floor1_nikolai_rtv_is_auto";
        }
      ];
      mode = "single";
    }
  ];

  binary_sensor = [
    {
      platform = "ping";
      host = "ndesk";
      name = "ndesk";
      count = 2;
      scan_interval = 30;
    }
    {
      platform = "ping";
      host = "flaptop-CP80173";
      name = "flaptop";
      count = 2;
      scan_interval = 30;
    }
  ];
}