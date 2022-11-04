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
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data.preset_mode = "manual";
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_hvac_mode";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data = {
            hvac_mode = "heat";
          };
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data = {
            temperature = 19.5;
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
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor1_nikolai_rtv_na";
          data.preset_mode = "manual";
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_hvac_mode";
          target.entity_id = "climate.floor0_nikolai_rtv_na";
          data = {
            hvac_mode = "heat";
          };
        }
        {
          delay = "0:00:01";
        }
        {
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_nikolai_rtv_na";
          data = {
            temperature = 19.5;
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
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data = {
            hvac_mode = "auto";
            temperature = "{{ states('number.floor0_bureau_rtv_na_current_heating_setpoint_auto') }}";
          };
        }
        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor0_bureau_rtv_na";
          data.preset_mode = "schedule";
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
	        service = "climate.set_temperature";
          target.entity_id = "climate.floor1_nikolai_rtv_na";
          data = {
            hvac_mode = "auto";
            temperature = "{{ states('number.floor1_nikolai_rtv_na_current_heating_setpoint_auto') }}";
          };
        }
        {
	        service = "climate.set_preset_mode";
          target.entity_id = "climate.floor1_nikolai_rtv_na";
          data.preset_mode = "schedule";
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