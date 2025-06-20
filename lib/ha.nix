{ lib, ... }:

let

  genId = id: (lib.strings.toLower (builtins.replaceStrings [ "/" "." " " ] [ "_" "_" "_" ] id));
  
  sensor = {
    temperature = name: value: {
      name = name;
      unique_id = genId name;
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

    avg_from_list = name: sensors: { unit_of_measurement, device_class, adjustments ? [], icon ? "" }: {
      name = name;
      state = ''
        {% set values = [
          ${builtins.concatStringsSep "," sensors}
        ]
        %}
        {% set valid_values = values | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
        {% set valid_adjustments = [
          ${builtins.concatStringsSep "," (builtins.map (i: if i < builtins.length adjustments then toString (builtins.elemAt adjustments i) else "0.0") (builtins.genList (x: x) (builtins.length sensors)))}
        ]
        %}
        {% if valid_values | length %}
          {% set adjusted_values = namespace(values=[]) %}
          {% for i in range(valid_values | length) %}
            {% set adjusted_values.values = adjusted_values.values + [(valid_values[i] + (valid_adjustments[i] | float))] %}
          {% endfor %}
          {{ (adjusted_values.values | sum / adjusted_values.values | length) | round(2) }}
        {% endif %}
      '';
      unit_of_measurement = unit_of_measurement;
      device_class = device_class;
      state_class = "measurement";
      availability = ''
        {% set v = [
          ${builtins.concatStringsSep "," sensors}
        ]
        %}
        {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
        {{ (valid_v | length) > 0 }}
      '';
      icon = icon;
    };

    max_from_list = name: sensors: { unit_of_measurement, device_class, icon ? "" }: {
      name = name;
      state = ''
        {% set v = [
          ${builtins.concatStringsSep "," sensors}
        ]
        %}
        {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
        {% if valid_v | length %}
          {{ max(valid_v) | round(2) }}
        {% endif %}
      '';
      unit_of_measurement = unit_of_measurement;
      device_class = device_class;
      state_class = "measurement";    
      availability = ''
        {% set v = [
          ${builtins.concatStringsSep "," sensors}
        ]
        %}
        {% set valid_v = v | select('!=','unknown') | select('!=','unavailable') | map('float') | list %}
        {{ (valid_v | length) > 0 }}
      '';
      icon = icon;
    };
  };

  automation = name: { triggers ? [ ], conditions ? [ ], actions ? [ ], mode ? "single", max_exceeded ? "warning" }: {
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

  automationToggle = name: { triggers ? [ ], conditions ? [ ], entities ? [ ], mode ? "single" }: [
    (automation "${name}.toggle" {
      triggers = triggers;   
      conditions = conditions;
      actions = map (entity: (action.toggle entity)) entities;
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

    toggle = entity: {
      service = "${lib.head (lib.strings.splitString "." entity)}.toggle";
      target.entity_id = entity;
    };

    set_value = entity: value: let
      head = lib.head (lib.strings.splitString "." entity);
      is_select = head == "select" || head == "input_select";
      service_name = if is_select then "select_option" else "set_value";
    in {
      service = "${head}.${service_name}";
      target.entity_id = entity;
      data = if is_select then { option = value; } else { value = value; };
    };

    valve_open = entity: {
      service = "valve.open_valve";
      target.entity_id = entity;
    };

    valve_close = entity: {
      service = "valve.close_valve";
      target.entity_id = entity;
    };

    delay = time: {
      delay = time;
    };

    mqtt_publish = topic: payload: retain: {
      service = "mqtt.publish";
      data = {
        topic = topic;
        payload = payload;
        retain = retain;
      };
    };
    
    automation = automation_name: {
      service = "automation.trigger";
      target.entity_id = "automation.${automation_name}";
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

    increment = entity: {
      service = "input_number.increment";
      target.entity_id = entity;
    };
    
  };

  trigger = rec {

    at = time: {
      platform = "time";
      at = time;
    };

    time_pattern_minutes = pattern: {
      platform = "time_pattern";
      minutes = pattern;
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

    state_for = name: for: {
      platform = "state";
      entity_id = name;
      for = for;
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

    below = entity: threshold: {
      platform = "numeric_state";
      entity_id = entity;
      below = threshold;
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

    above = entity: number: {
      condition = "numeric_state";
      entity_id = entity;
      above = number;
    };

    between = entity: low: high: {
      condition = "numeric_state";
      entity_id = entity;
      above = low;
      below = high;
    };

    template = template: {
      condition = "template";
      value_template = template;
    };

  };
in

{

  genId = genId;
  sensor = sensor;
  automation = automation;
  automationOnOff = automationOnOff;
  automationToggle = automationToggle;
  action = action;
  trigger = trigger;
  condition = condition;

  utility_meter = name: source: cycle: {
    "${name}_${cycle}" = {
      source = source;
      cycle = cycle;
    };
  };
}
