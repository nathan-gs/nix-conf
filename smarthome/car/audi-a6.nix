{ ... }:
let
  # Two integrations report the same car and neither is reliable on its own:
  #
  #  - Audi Connect (audiconnect, sensor.audi_a6_sportback_e_tron_*) polls Audi's
  #    backend every 15 minutes and is fresh when it works, but Audi broke its
  #    login for a month (2026-10-12 → v2.5.2 on 2026-11-10) and may do so again.
  #  - EU Data Act (cupra_eu_data_act, sensor.car_car_a6_*) cannot be banned, but
  #    the portal replays data hours late: its entity is always "available", so
  #    only the `data_captured_at` attribute says how old a reading really is.
  #
  # The car/audi-a6/* sensors below are the only ones the rest of the config
  # should read. Each picks whichever source carries the newer car-captured
  # timestamp, so a lagging Data Act feed loses to a working Audi Connect and a
  # dead Audi Connect falls back to Data Act without anyone editing templates.
  # Both timestamps are the car's own clock: Audi Connect's "Last Update" is the
  # newest carCapturedTimestamp it saw, Data Act's is the per-field
  # data_captured_at. Never use last_updated/last_changed of either entity for
  # this — those say when HA polled, not when the car reported.
  ac = {
    last_update = "sensor.audi_a6_sportback_e_tron_last_update";
    battery = "sensor.audi_a6_sportback_e_tron_state_of_charge";
    mileage = "sensor.audi_a6_sportback_e_tron_mileage";
    range = "sensor.audi_a6_sportback_e_tron_range";
  };
  da = {
    battery = "sensor.car_car_a6_battery";
    mileage = "sensor.car_car_a6_mileage";
    range = "sensor.car_car_a6_range_combined";
  };

  source = "sensor.car_audi_a6_source";

  # Jinja prologue that leaves `src` ('audi_connect' | 'data_act' | 'none') and
  # `ts` (that source's car-captured timestamp or none) set. Inlined wherever the
  # choice is needed instead of read back through `this`, because inside one
  # render `this` is still the previous state and would lag a cycle.
  selectSource = ''
    {% set ac_ok = is_number(states('${ac.battery}')) %}
    {% set da_ok = is_number(states('${da.battery}')) %}
    {% set ac_ts = states('${ac.last_update}') | as_datetime(none) if ac_ok else none %}
    {% set da_ts = state_attr('${da.battery}', 'data_captured_at') | as_datetime(none) if da_ok else none %}
    {% if ac_ok and (not da_ok or da_ts is none or (ac_ts is not none and ac_ts >= da_ts)) %}
      {% set src, ts = 'audi_connect', ac_ts %}
    {% elif da_ok %}
      {% set src, ts = 'data_act', da_ts %}
    {% else %}
      {% set src, ts = 'none', none %}
    {% endif %}
  '';

  # Reads the field from the source the selector picked. A source is only picked
  # when it had a numeric battery value, so the fallthrough to `none` happens
  # while both integrations are down.
  pickState = field: ''
    {% set src = states('${source}') %}
    {% if src == 'audi_connect' %}
      {{ states('${ac.${field}}') }}
    {% elif src == 'data_act' %}
      {{ states('${da.${field}}') }}
    {% else %}
      {{ none }}
    {% endif %}
  '';
  eitherAvailable = field: ''
    {{ is_number(states('${ac.${field}}')) or is_number(states('${da.${field}}')) }}
  '';
  sourceAttributes = {
    source = "{{ states('${source}') }}";
    captured_at = "{{ state_attr('${source}', 'captured_at') }}";
    age_minutes = "{{ state_attr('${source}', 'age_minutes') }}";
  };
in
{
  services.home-assistant.config.template = [
    {
      sensor = [
        {
          # Which integration currently has the fresher car snapshot. Decided on
          # the battery reading, since that is what the charger logic lives on.
          # Audi Connect wins ties: when both saw the same car upload it is the
          # one that will see the next one first.
          name = "car/audi-a6/source";
          unique_id = "car_audi_a6_source";
          icon = "mdi:source-branch";
          state = ''
            ${selectSource}
            {{ src }}
          '';
          attributes = {
            captured_at = ''
              ${selectSource}
              {{ ts }}
            '';
            age_minutes = ''
              ${selectSource}
              {{ ((now() - ts).total_seconds() / 60) | round(0) | int if ts is not none else none }}
            '';
            audi_connect_captured_at = "{{ states('${ac.last_update}') | as_datetime(none) }}";
            data_act_captured_at = "{{ state_attr('${da.battery}', 'data_captured_at') | as_datetime(none) }}";
          };
        }
        {
          name = "car/audi-a6/battery";
          unique_id = "car_audi_a6_battery";
          device_class = "battery";
          state_class = "measurement";
          unit_of_measurement = "%";
          state = pickState "battery";
          availability = eitherAvailable "battery";
          attributes = sourceAttributes;
        }
        {
          # Odometer. Not "the fresher source" but the larger reading: an
          # odometer only ever goes up, so the higher value is by definition the
          # newer one, and the utility meters built on this treat a drop as a
          # meter reset and would book the whole odometer as one month's driving.
          name = "car/audi-a6/mileage";
          unique_id = "car_audi_a6_mileage";
          device_class = "distance";
          state_class = "total_increasing";
          unit_of_measurement = "km";
          icon = "mdi:counter";
          state = ''
            {% set vals = [states('${ac.mileage}'), states('${da.mileage}')] | select('is_number') | map('float') | list %}
            {{ (vals | max) | round(0) | int if vals else none }}
          '';
          availability = eitherAvailable "mileage";
          attributes = {
            source = ''
              {% set ac_v = states('${ac.mileage}') %}
              {% set da_v = states('${da.mileage}') %}
              {% if is_number(ac_v) and (not is_number(da_v) or ac_v | float >= da_v | float) %}
                audi_connect
              {% elif is_number(da_v) %}
                data_act
              {% else %}
                {{ none }}
              {% endif %}
            '';
            captured_at = ''
              {% set ac_v = states('${ac.mileage}') %}
              {% set da_v = states('${da.mileage}') %}
              {% if is_number(ac_v) and (not is_number(da_v) or ac_v | float >= da_v | float) %}
                {{ states('${ac.last_update}') | as_datetime(none) }}
              {% elif is_number(da_v) %}
                {{ state_attr('${da.mileage}', 'data_captured_at') | as_datetime(none) }}
              {% else %}
                {{ none }}
              {% endif %}
            '';
          };
        }
        {
          name = "car/audi-a6/range";
          unique_id = "car_audi_a6_range";
          device_class = "distance";
          state_class = "measurement";
          unit_of_measurement = "km";
          icon = "mdi:map-marker-distance";
          state = pickState "range";
          availability = eitherAvailable "range";
          attributes = sourceAttributes;
        }
      ];
    }
  ];
}
