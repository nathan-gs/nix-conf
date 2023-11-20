{ lib, ... }:

let

  sensor = {
    temperature = name: value: {
      name = name;
      state = value;
      unit_of_measurement = "°C";
      device_class = "temperature";
      icon = "mdi:thermometer-auto";
    };
  };

  automation = name: { triggers ? [ ], conditions ? [ ], actions ? [ ], mode ? "single" }: {
    id = builtins.replaceStrings [ "/" "." ] [ "_" "_" ] name;
    alias = name;
    trigger = triggers;
    condition = conditions;
    action = actions;
    mode = mode;
  };

  automationOnOff = name: { triggersOn ? [ ], triggersOff ? [ ], conditionsOn ? [ ], conditionsOff ? [ ], entities ? [ ], mode ? "single" }: [
    (automation "${name}.turn_on" {
      triggers = triggersOn;
      conditions = conditionsOn;
      actions = map (entity: (action.on entity)) entities;
      mode = mode;
    })
    (automation "${name}.turn_off" {
      triggers = triggersOff;
      conditions = conditionsOff;
      actions = map (entity: (action.off entity)) entities;
      mode = mode;
    })
  ];

  action = {

    on = entity: {
      service = "${lib.head (lib.strings.splitString "." entity)}.turn_on";
      target.entity_id = entity;
    };

    off = entity: {
      service = "${lib.head (lib.strings.splitString "." entity)}.turn_off";
      target.entity_id = entity;
    };

  };

  trigger = {

    at = time: {
      platform = "time";
      at = time;
    };

    state_to = name: to: {
      platform = "state";
      entity_id = name;
      to = to;
    };
  };
in

{

  sensor = sensor;
  automation = automation;
  automationOnOff = automationOnOff;
  action = action;
  trigger = trigger;

}
