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

    delay = time: {
      delay = time;
    };

    mqttPublish = topic: payload: retain: {
      service = "mqtt.publish";
      data = {
        topic = topic;
        payload_template = payload;
        retain = retain;
      };
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

    state = name: {
      platform = "state";
      entity_id = name;
    };
  };

  condition = {
    state = entity: state: {
      condition = "state";
      entity_id = entity;
      state = state;
    };

    time_after = time: {
      condition = "time";
      after = time;      
    };
  };
in

{

  sensor = sensor;
  automation = automation;
  automationOnOff = automationOnOff;
  action = action;
  trigger = trigger;
  condition = condition;
}
