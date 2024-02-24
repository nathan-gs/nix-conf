{ lib, ... }:

let

  genId = id: (lib.strings.toLower (builtins.replaceStrings [ "/" "." " " ] [ "_" "_" "_" ] id));
  
  sensor = {
    temperature = name: value: {
      name = name;
      state = value;
      unit_of_measurement = "°C";
      device_class = "temperature";
      icon = "mdi:thermometer-auto";
      state_class = "measurement";
    };

    battery_from_attr = name: source: {
      name = name;
      state = ''
        {{ state_attr('${source}', 'battery') | int(0) }}
      '';
      device_class = "battery";
      unit_of_measurement = "%";
      state_class = "measurement";
    };

    battery_from_3v_voltage_attr = name: source: {
      name = name;
      unique_id = genId name;
      state = ''
        {{ (((state_attr('${source}', 'voltage') | int(0) * 2) / 3000) * 100) | round(0) }}
      '';
      device_class = "battery";
      unit_of_measurement = "%";
      state_class = "measurement";
    };

    energy_demand_remaining = appliance: condition: template: {
      name = "electricity/demand_management/${appliance}.energy_remaining";
      unique_id = genId "electricity/demand_management/${appliance}.energy_remaining";
      device_class = "energy";
      state = ''
        {% if ${condition} %}
          ${template}
        {% else %}
          0
        {% endif %}
      '';
      unit_of_measurement = "kWh";
    };
  };

  automation = name: { triggers ? [ ], conditions ? [ ], actions ? [ ], mode ? "single" }: {
    id = genId name;
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

    persistent_notification = {
      create = id: title: message: {
        service = "persistent_notification.create";
        data = {
          notification_id = id;
          title = title;
          message = message;
        };
      };
      
      dismiss = id: {
        service = "persistent_notification.dismiss";
        data.notification_id = id;
      };
    };

    conditional = conditions: actions: alternatives: {
      "if" = conditions;
      "then" = actions;
      "else" = alternatives;
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

    state_attr = name: attribute: {
      platform = "state";
      entity_id = name;
      attribute = attribute;
      to = "~";
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

    below = entity: number: {
      condition = "numeric_state";
      entity_id = entity;
      below = number;
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
