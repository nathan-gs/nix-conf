{ config, pkgs, lib, ha, ... }:
let
  # Reconstructs a high-precision, never-resetting lifetime total by adding
  # a Modbus daily counter (1 decimal, resets at local midnight) onto a
  # `till_yesterday` baseline - rather than reading the inverter's own
  # lifetime register directly, which is whole-units-only and once had a
  # same-day continuity gap when the solis_modbus entity was recreated
  # during the cloud retirement. The lifetime register is still used, just
  # only as a periodic anchor for `till_yesterday` (see below) rather than
  # as the live-updating total itself.
  #
  # Pattern carried over from the retired solis_local.nix .cgi scrape
  # (solar_delivery_total / _till_yesterday): a helper holds the running
  # total as of yesterday, and the running total itself is
  # till_yesterday + today. The .cgi sensor briefly re-reported the previous
  # day's total for hours after midnight, so this used to freeze 23:00-03:00
  # as a precaution - but the Modbus daily counter resets cleanly to 0 at
  # local midnight (verified across multiple nights, no stale re-reporting),
  # and the freeze itself was the bug: it held the total flat all night and
  # then jumped by the whole overnight discharge/charge in one step at 03:00,
  # which read as "sensor stopped updating, then caught up".
  #
  # till_yesterday is an input_number, not a trigger-based template sensor -
  # trigger-based template sensors don't restore their state across HA
  # restarts (there's no "restore" option in this HA version's template
  # schema; setting one makes the whole template block fail validation).
  #
  # input_number's own restore is not reliable enough to trust on its own -
  # after a crash-loop restart (2026-08-21, electrolux_status integration)
  # it came back pinned at its `initial` of 0 instead of its last value, and
  # sat there for 45+ minutes (previously it self-healed within ~30 min of a
  # restart; this time it didn't), dragging the whole reconstructed total
  # down to just that day's fraction. So till_yesterday is never trusted
  # in-place: `lifetimeSource` is the inverter's own lifetime register
  # (whole kWh, always live off Modbus - no restore involved at all) and
  # till_yesterday is *recomputed* from it (lifetime minus today's already-
  # counted fraction) both at midnight and on every HA start, so a bad
  # restore self-heals within seconds of startup instead of waiting up to a
  # day for the next midnight snapshot. lifetimeSource is only ever read at
  # those two moments - `today`'s finer 1-decimal resolution is still what
  # drives the total through the rest of the day.
  mkReconstructedTotal = { name, dailySource, lifetimeSource, icon }:
    let
      tillYesterdayName = "${name}_till_yesterday";
      entityId = "sensor.${ha.genId name}";
      tillYesterdayObjectId = ha.genId tillYesterdayName;
      tillYesterdayEntityId = "input_number.${tillYesterdayObjectId}";
      tillYesterdayFromLifetime = ''
        {{ (states('${lifetimeSource}') | float(0)) - (states('${dailySource}') | float(0)) }}
      '';
    in {
      inherit entityId tillYesterdayObjectId;
      tillYesterdayHelper = {
        name = tillYesterdayName;
        min = 0;
        max = 1000000;
        step = 0.1;
        mode = "box";
        unit_of_measurement = "kWh";
        icon = icon;
        initial = 0;
      };
      snapshotAutomation = ha.automation "${name}.snapshot_till_yesterday" {
        triggers = [
          (ha.trigger.at "00:00:00")
          { platform = "homeassistant"; event = "start"; }
        ];
        actions = [
          # Modbus/solis_modbus setup can take well over a minute after HA
          # starts (seen taking 60s+ in practice) - give it time to connect
          # before trusting its readings. Harmless at the midnight trigger
          # too, Modbus is already up by then.
          (ha.action.delay "00:02:00")
          (ha.action.conditional
            [ (ha.condition.template ''
                {{ states('${lifetimeSource}') not in ['unknown', 'unavailable', 'none']
                   and states('${dailySource}') not in ['unknown', 'unavailable', 'none'] }}
              '')
            ]
            [ (ha.action.set_value tillYesterdayEntityId tillYesterdayFromLifetime) ]
            [ ]
          )
        ];
      };
      sensorEntry = {
        inherit name icon;
        unique_id = ha.genId name;
        state = ''
          {% set till_yesterday = states('${tillYesterdayEntityId}') | float(0) %}
          {% set today = states('${dailySource}') | float(0) %}
          {{ till_yesterday + today }}
        '';
        # A bad till_yesterday restore isn't just "unavailable" - it comes
        # back as a plausible-looking number (its `initial` of 0), so a
        # not-unknown/unavailable check on the inputs alone doesn't catch it
        # (2026-08-21: this happened twice, each time producing a huge false
        # total_increasing "reset" followed by an equally huge false
        # "recovery" once corrected - which the Energy dashboard statistics
        # read as genuine energy and had to be corrected by hand). Cross-check
        # instead against `lifetimeSource`, which has no restore step to fail
        # (always a live Modbus read) and tracks the true total to within
        # ~1 kWh at all times - if the reconstructed total disagrees with it
        # by more than a real day's worth of activity ever could, something
        # upstream is wrong and this entity should go unavailable rather than
        # publish a number and let a `total_increasing` sensor "fix" it later.
        availability = ''
          {% set lifetime = states('${lifetimeSource}') %}
          {% if lifetime in ['unknown', 'unavailable', 'none'] %}
            false
          {% else %}
            {% set till_yesterday = states('${tillYesterdayEntityId}') | float(0) %}
            {% set today = states('${dailySource}') | float(0) %}
            {{ ((till_yesterday + today) - (lifetime | float(0))) | abs < 5 }}
          {% endif %}
        '';
        unit_of_measurement = "kWh";
        device_class = "energy";
        state_class = "total_increasing";
      };
    };

  # `solar/total_energy_generation`, `battery/charge_total_energy` and
  # `battery/discharge_total_energy` are the sums across inverters/battery
  # banks (today just the one house plant) - these are the entities the
  # Energy dashboard should point at. Add a second `solar/<name>/...` /
  # `battery/<name>/...` pair here and extend the matching sum when a
  # second inverter shows up.
  solarGeneration = mkReconstructedTotal {
    name = "solar/house/total_energy_generation";
    dailySource = "sensor.system_house_pv_pv_today_energy_generation";
    lifetimeSource = "sensor.system_house_pv_pv_total_energy_generation";
    icon = "mdi:solar-panel";
  };
  batteryCharge = mkReconstructedTotal {
    name = "battery/house/charge_total_energy";
    dailySource = "sensor.system_house_pv_today_battery_charge_energy";
    lifetimeSource = "sensor.system_house_pv_total_battery_charge_energy";
    icon = "mdi:battery-plus";
  };
  batteryDischarge = mkReconstructedTotal {
    name = "battery/house/discharge_total_energy";
    dailySource = "sensor.system_house_pv_today_battery_discharge_energy";
    lifetimeSource = "sensor.system_house_pv_total_battery_discharge_energy";
    icon = "mdi:battery-minus";
  };

  perInverter = [ solarGeneration batteryCharge batteryDischarge ];

  # Mirrors must propagate the source's availability too, not just its state -
  # `states(x) | float(0)` silently turns "unavailable" into 0, which would
  # reintroduce the exact false-reset problem the availability guard above
  # exists to prevent, just one hop downstream.
  mkAggregate = { name, icon, source }: {
    inherit name icon;
    unique_id = ha.genId name;
    state = "{{ states('${source}') | float(0) }}";
    availability = "{{ states('${source}') not in ['unknown', 'unavailable', 'none'] }}";
    unit_of_measurement = "kWh";
    device_class = "energy";
    state_class = "total_increasing";
  };

  aggregates = [
    (mkAggregate {
      name = "solar/total_energy_generation";
      icon = "mdi:solar-panel";
      source = solarGeneration.entityId;
    })
    (mkAggregate {
      name = "battery/charge_total_energy";
      icon = "mdi:battery-plus";
      source = batteryCharge.entityId;
    })
    (mkAggregate {
      name = "battery/discharge_total_energy";
      icon = "mdi:battery-minus";
      source = batteryDischarge.entityId;
    })
  ];
in
{
  services.home-assistant.config = {
    input_number = builtins.listToAttrs (map (x: {
      name = x.tillYesterdayObjectId;
      value = x.tillYesterdayHelper;
    }) perInverter);

    automation = map (x: x.snapshotAutomation) perInverter;

    template = [
      {
        sensor = (map (x: x.sensorEntry) perInverter) ++ aggregates;
      }
    ];
  };
}
