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

    battery_from_attr = name: source: {
      name = name;
      state = ''
        {{ state_attr('${source}', 'battery') | int(0) }}
      '';
      device_class = "battery";
      unit_of_measurement = "%";
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

    notify = title: message: {
      service = "notify.notify";
      data = {
        title = title;
        message = message;
      };      
    };
    
  };

  trigger = rec {

    at = time: {
      platform = "time";
      at = time;
    };

    state_to = name: to: {
      platform = "state";
      entity_id = name;
      to = to;
    };


    state_to_for = name: to: for: {
      platform = "state";
      entity_id = name;
      to = to;
      for = for;
    };

    state = name: {
      platform = "state";
      entity_id = name;
    };

    on = name: state_to name "on";

    off = name: state_to name "off";

    on_for = name: for: state_to_for name "on" for;

    off_for = name: for: state_to_for name "off" for;

    above = entity: threshold: {
      platform = "numeric_state";
      entity_id = entity;
      above = threshold;
    };

    tag = id: {
      platform = "tag";
      tag_id = id;
    };

    template_for = template: for: {
      platform = "template";
      value_template = template;
      for = for;
    };

    template = template: template_for template "00:00:00";
    
  };

  condition = rec {
    state = entity: state: {
      condition = "state";
      entity_id = entity;
      state = state;
    };

    time_after = time: {
      condition = "time";
      after = time;      
    };

    on = name: state name "on";

    off = name: state name "off";

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
