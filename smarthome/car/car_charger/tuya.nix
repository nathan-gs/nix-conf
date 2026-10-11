{ ha, ... }:

{

  services.home-assistant.config = {

    input_boolean = {
      # Set by the 21:00 "plan tomorrow" automation from the solar forecast, so the
      # actionable notification's "Home" reply knows whether to grid-charge to 60% (sunny,
      # solar tops up) or 70% (dull day). See car_charger.plan_tomorrow below.
      car_charge_sunny_tomorrow = {
        name = "car/charge_sunny_tomorrow";
        icon = "mdi:weather-sunny";
      };
      # Set by the morning battery boost automation (re-evaluated every 15 min from 05:00 to
      # 07:00) when the solar forecast is >= 9 kWh and the home battery holds meaningfully
      # more than input_number.car_charge_boost_floor. Charging runs until the battery reaches
      # that floor (gated in should_charge below), then car_charger.morning_battery_boost_done
      # clears this flag. Also cleared at 09:00 and reset nightly at 21:00 by plan_tomorrow, so
      # a battery that solar refills past the floor cannot silently re-arm the boost during
      # peak hours.
      car_charge_morning_boost = {
        name = "car/charge_morning_boost";
        icon = "mdi:battery-arrow-up";
      };
    };

    input_number = {
      # Overnight grid-charge ceiling (%). The offpeak charger fills to this SoC from the
      # grid; solar tops up the rest during the day. Default 70; the plan_tomorrow flow
      # drops it to 60 on a sunny day or raises it to 100 for a long drive, and resets it
      # to 70 each evening before re-asking.
      # No `initial` so the value restores across HA restarts (a nightly "long drive" 100%
      # survives a 3am restart mid-charge). On the very first boot it comes up at `min`, so
      # min is 50 — the lowest intended target — not something that would starve the charge.
      car_charge_grid_target = {
        name = "car/charge_grid_target";
        icon = "mdi:battery-charging-70";
        min = 40;
        max = 100;
        step = 5;
        unit_of_measurement = "%";
        mode = "slider";
      };

      # Dynamic stop floor (%) for the morning battery boost, recomputed every 15 min from
      # 05:00 by car_charger.morning_battery_boost. It is the SoC the pack must keep back to
      # carry the house on its own until solar out-produces the baseload — the point of the
      # boost is to move stored energy into the car, not to hand the house over to the grid at
      # 07:00. Written by the automation, read by should_charge and by
      # morning_battery_boost_done; never set by hand.
      car_charge_boost_floor = {
        name = "car/charge_boost_floor";
        icon = "mdi:battery-lock";
        min = 10;
        max = 60;
        step = 1;
        unit_of_measurement = "%";
        mode = "box";
      };
    };

    input_select = {
      car_charge_override = {
        name = "car/charge_override";
        icon = "mdi:car-electric";
        options = [ "auto" "auto + battery" "on" "battery drain" "solar+grid boost" "solar+grid 16a" "off" ];
      };
      system_car_charger_current_override_a = {
        name = "system/car_charger/current_override_a";
        icon = "mdi:current-ac";
        options = [ "auto" "6"  "8" "10" "13" "16" ]; 
      };
    };


    template = [
      {
        sensor = [
          {
            # Single source of truth for what each input_select.car_charge_override entry
            # actually does. force_on / boost / cap are the ONLY things that vary by mode —
            # everything else (low_soc, should_charge_offpeak, solar_eligible, morning_boost,
            # rebalance, capacity_critical in should_charge; headroom/solar-throttle in
            # target_current) applies the same regardless of mode.
            #
            #   mode               force charge on    boost (skip solar throttle)   cap
            #   auto               no                 only if offpeak+sunny+below   13A
            #                                          target (auto_boost, below)
            #   auto + battery     no                 no (solar throttle itself     13A
            #                                          reserves 500W for the house
            #                                          battery — see target_current)
            #   on                 yes                no                            13A
            #   battery drain      while soc > 20%     while soc > 20%              13A
            #   solar+grid boost   yes                yes                           13A
            #   solar+grid 16a     yes                yes                           16A
            #   off                no                 no                            13A (moot —
            #                                                                       should_charge
            #                                                                       is forced off)
            name = "system/car_charger/override_mode";
            unique_id = "system_car_charger_override_mode";
            icon = "mdi:car-electric";
            state = "{{ states('input_select.car_charge_override') }}";
            attributes = {
              force_on = ''
                {% set override = states('input_select.car_charge_override') %}
                {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
                {{ override in ['on', 'solar+grid boost', 'solar+grid 16a']
                   or (override == 'battery drain' and battery > 20) }}
              '';
              boost = ''
                {% set override = states('input_select.car_charge_override') %}
                {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
                {# "sunny" here is real-time solar output (solar_boost, solar > 1000 W), not the
                   forecast-based car_charge_sunny_tomorrow, which is set the evening before for
                   the next day's plan — the wrong signal for a live "is it sunny now" check. #}
                {% set offpeak = is_state('binary_sensor.electricity_is_offpeak', 'on') %}
                {% set sunny = is_state('binary_sensor.system_car_charger_solar_boost', 'on') %}
                {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
                {% set target = states('input_number.car_charge_grid_target') | float(70) %}
                {{ override in ['solar+grid boost', 'solar+grid 16a']
                   or (override == 'battery drain' and battery > 20)
                   or (override == 'auto' and offpeak and sunny and soc < target) }}
              '';
              cap = "{{ 16 if states('input_select.car_charge_override') == 'solar+grid 16a' else 13 }}";
            };
          }
          {
            # The current cap (A) for this charge mode, before headroom/peak-shaving scale it
            # down further. Split out of target_current so the "what mode am I in" decision is
            # readable on its own, separate from the "how much headroom is there right now" math.
            name = "system/car_charger/current_cap";
            unique_id = "system_car_charger_current_cap";
            unit_of_measurement = "A";
            device_class = "current";
            state_class = "measurement";
            icon = "mdi:current-ac";
            state = ''
              {% set cap = state_attr('sensor.system_car_charger_override_mode', 'cap') | int(13) %}
              {# The manual current override is a MAX, not a fixed value — headroom/peak-shaving
                 in target_current can still scale the actual current down under it. A hard fixed
                 value ignored the capacity tariff and grid headroom entirely, which let the
                 charger sit at a current the house couldn't sustain. #}
              {% set override = states('input_select.system_car_charger_current_override_a') | int(0) %}
              {% if override > 0 %}
                {% set cap = min(cap, override) %}
              {% endif %}
              {{ cap }}
            '';
          }
          {
            # How much current (A) the capaciteitstarief 15-min-average cap allows right now,
            # ignoring solar-throttle and mode cap — see binary_sensor.system_car_charger_capacity_near
            # and docs/ev-battery-peak-coordination.md for why this is two different calculations
            # depending on where we are in the quarter.
            name = "system/car_charger/capacity_headroom_current";
            unique_id = "system_car_charger_capacity_headroom_current";
            unit_of_measurement = "A";
            device_class = "current";
            state_class = "measurement";
            icon = "mdi:transmission-tower-import";
            state = ''
              {# Capaciteitstarief floor is 2.5 kW — no point throttling for a lower "peak". #}
              {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(0) %}
              {# Aim 0.3 kW UNDER the peak, not at it. The battery no longer shaves peaks (its floor
                 never drops below 15%, see solar/battery.nix), so the car is the only thing keeping
                 the quarter's average at or under the cap; aiming exactly at it left no room for
                 house load rising mid-quarter and is what let the old deep-discharge branch fire. #}
              {% set capacity_kw = max(monthly_peak, 2.5) - 0.3 %}
              {# END-OF-QUARTER peak shaving. The capaciteitstarief peak is the 15-MINUTE AVERAGE of
                 grid import, so we charge hard while little of the quarter is committed, then drop
                 to 6A for the tail so the average lands under the cap. #}
              {% if is_state('binary_sensor.system_car_charger_capacity_near', 'on') %}
                {{ 6 }}
              {% else %}
                {# front of the quarter: charge at whatever the cap allows, computed from headroom
                   (scales with monthly_peak) rather than a fixed current. #}
                {% set estimated_15m = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
                {% set charger_kw = states('sensor.car_charger_power') | int(0) / 1000 %}
                {% set headroom_kw = capacity_kw - (estimated_15m - charger_kw) %}
                {{ (headroom_kw * 1000 / 230) | round(0) | int }}
              {% endif %}
            '';
          }
          {
            name = "system/car_charger/target_current";
            unique_id = "system_car_charger_target_current";
            unit_of_measurement = "A";
            device_class = "current";
            state_class = "measurement";
            icon = "mdi:current-ac";
            state = ''
              {# Start from the capacity-tariff headroom (or its 6A end-of-quarter tail — see
                 capacity_headroom_current and binary_sensor.system_car_charger_capacity_near),
                 throttle to available solar unless boosting, then clamp to this mode's cap and
                 quantize down to a step the charger accepts (steps[0] = 6A is always the floor —
                 select() below returns nothing below it, so `or [steps[0]]` catches that). #}
              {% set steps = [6, 8, 10, 13, 16] %}
              {% set battery_mode = states('input_select.car_charge_override') == 'auto + battery' %}
              {% set boost = is_state('binary_sensor.system_car_charger_boost_active', 'on') %}
              {% set cap = states('sensor.system_car_charger_current_cap') | int(13) %}
              {% set target_a = states('sensor.system_car_charger_capacity_headroom_current') | int(6) %}
              {% if is_state('binary_sensor.system_car_charger_solar_boost', 'on') and not boost %}
                {% set solar = states('sensor.electricity_solar_power_mean_15m') | float(0) %}
                {# auto + battery reserves 500W for the home battery and caps at 8A; every other
                   mode caps at 16A and, when the battery's comfortably charged (50-80%) with
                   plenty of solar still to come today, gets a floor bump to 13A regardless of the
                   raw solar reading. #}
                {% set reserve_w = 500 if battery_mode else 0 %}
                {% set solar_cap = 8 if battery_mode else 16 %}
                {% set solar_a = [0, ((solar - reserve_w) / 230) | round(0) | int] | max %}
                {% set target_a = min(solar_cap, solar_a) %}
                {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
                {% set remaining_energy = states('sensor.energy_production_today_remaining') | float(0) %}
                {% if not battery_mode and battery > 50 and battery <= 80 and remaining_energy > 5 %}
                  {% set target_a = 13 %}
                {% endif %}
              {% endif %}
              {% set target_a = min(target_a, cap) %}
              {{ (steps | select('le', target_a) | list or [steps[0]]) | max }}
            '';
          }
        ];
        binary_sensor = [
          {
            # Has this quarter's banked 15-min average import climbed close enough to the
            # capaciteitstarief cap that the car needs to drop to its 6A tail?
            # `electricity_delivery_power_15m` (banked) only climbs within a quarter (and resets
            # each quarter) — it cannot un-cross this threshold once true, so unlike the
            # front-of-quarter headroom calc it is safe for set_current to react to immediately,
            # with no debounce.
            #
            # Margin widened 0.3 -> 0.5 kW when set_current debounced for 1 min and stepped every
            # 2 min, so 13A -> 6A could take ~4 min once this tripped. The step delay is 45s now
            # (see set_current), so 13A -> 6A is ~1.5 min and this margin is conservative. It still
            # triggers early enough that the average lands under the cap.
            name = "system/car_charger/capacity_near";
            unique_id = "system_car_charger_capacity_near";
            icon = "mdi:meter-electric";
            state = ''
              {% set monthly_peak = states('sensor.electricity_delivery_power_monthly_15m_max') | float(0) %}
              {% set capacity_near = [2.1, monthly_peak - 0.8] | max %}
              {% set banked = states('sensor.electricity_delivery_power_15m') | float(0) %}
              {{ banked >= capacity_near }}
            '';
          }
          {
            # Peak-hour emergency floor: charge only when SoC is critically low.
            # Offpeak uses should_charge_offpeak + car_charge_grid_target (50/70/100).
            name = "system/car_charger/low_soc";
            unique_id = "system_car_charger_low_soc";
            icon = "mdi:battery-low";
            state = ''
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {{ soc < 35 }}
            '';
          }
          {
            name = "system/car_charger/should_charge_offpeak";
            unique_id = "system_car_charger_should_charge_offpeak";
            icon = "mdi:clock-outline";
            state = ''
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {% set offpeak = is_state('binary_sensor.electricity_is_offpeak', 'on') %}
              {# Grid-charge ceiling is set the evening before via the plan_tomorrow flow
                 (60 sunny / 70 default / 100 long drive); falls back to 70. #}
              {% set target = states('input_number.car_charge_grid_target') | float(70) %}
              {# On the solar-first plan (sunny + home, target 60) grid only guarantees the
                 floor OVERNIGHT — the daytime belongs to solar. This matters on weekends,
                 where offpeak runs all day and would otherwise let the grid pre-empt the sun.
                 Weekdays are unaffected (daytime is peak, so offpeak is already false). For
                 higher targets (dull / drive) there is no solar to protect, so daytime
                 offpeak grid charging stays enabled. #}
              {% set solar_first = target <= 60 %}
              {% set daytime = is_state('sun.sun', 'above_horizon') %}
              {# Sunny (real-time solar, not last night's forecast) + low tariff + below target:
                 solar+grid boost (see target_current) takes over instead of ceding daytime to
                 solar-only, so the solar_first carve-out shouldn't block grid charging here. #}
              {% set sunny = is_state('binary_sensor.system_car_charger_solar_boost', 'on') %}
              {{ offpeak and soc < target and not (solar_first and daytime and not sunny) }}
            '';
          }
          {
            name = "system/car_charger/solar_charge_eligible";
            unique_id = "system_car_charger_solar_charge_eligible";
            icon = "mdi:solar-power";
            state = ''
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(10) %}
              {% set solar = states('sensor.electricity_solar_power_mean_15m') | float(0) %}
              {% set delivery = states('sensor.electricity_delivery_power_15m_estimated') | float(0) %}
              {{ solar > 1400 and delivery < 0.4 and battery > 15 }}
            '';
          }
          {
            name = "system/car_charger/solar_boost";
            unique_id = "system_car_charger_solar_boost";
            icon = "mdi:solar-power-variant";
            state = ''
              {% set soc = states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) %}
              {% set solar = states('sensor.electricity_solar_power_mean_15m') | float(0) %}
              {{ soc <= 80 and solar > 1000 }}
            '';
          }
          {
            # Should target_current charge at full current_cap instead of throttling to available
            # solar? See sensor.system_car_charger_override_mode's `boost` attribute for the
            # per-mode rule this mirrors.
            name = "system/car_charger/boost_active";
            unique_id = "system_car_charger_boost_active";
            icon = "mdi:lightning-bolt";
            state = "{{ state_attr('sensor.system_car_charger_override_mode', 'boost') }}";
          }
          {
            # The charger's own status DP — local and immediate, unlike the Audi Connect API
            # (cloud-polled, minutes behind: on 2026-08-29 this reported plugged_in/charging a
            # full 12 minutes before binary_sensor.audi_a6_sportback_e_tron_plug_state caught
            # up). Use this instead of anything Audi- or phone-derived for "is a car actually
            # attached to the charger".
            name = "system/car_charger/vehicle_connected";
            unique_id = "system_car_charger_vehicle_connected";
            icon = "mdi:ev-plug-type2";
            state = ''
              {{ states('sensor.system_car_charger_status') not in ['available', 'fault_unplugged', 'unavailable', 'unknown'] }}
            '';
          }
          {
            name = "system/car_charger/should_charge";
            unique_id = "system_car_charger_should_charge";
            icon = "mdi:car-electric";
            state = ''
              {% set override = states('input_select.car_charge_override') %}
              {# battery_sufficient (house battery > 10%) must gate ONLY solar charging — draining
                 the house battery to feed the car is wasteful. Grid charging (offpeak / low car
                 SoC / manual on) draws from the grid, so a low house battery must NOT stop it,
                 otherwise a battery drained by peak shaving hard-stops the car overnight. #}
              {% set battery_sufficient = is_state('binary_sensor.solar_battery_sufficient', 'on') %}
              {% set low_soc = is_state('binary_sensor.system_car_charger_low_soc', 'on') %}
              {% set should_charge_offpeak = is_state('binary_sensor.system_car_charger_should_charge_offpeak', 'on') %}
              {% set solar_eligible = is_state('binary_sensor.system_car_charger_solar_charge_eligible', 'on') and battery_sufficient %}
              {# force_on covers 'on' / 'solar+grid boost' / 'solar+grid 16a' plus 'battery drain'
                 phase 1 (house battery still above its 20% floor) — see
                 sensor.system_car_charger_override_mode for the full per-mode table. Phase 2 of
                 battery drain (battery <= 20%) is handled by solar_eligible naturally allowing
                 charging when there is enough solar production. #}
              {% set force_on = state_attr('sensor.system_car_charger_override_mode', 'force_on') %}
              {# Morning battery boost: drain home battery into car before solar arrives. Stops
                 at car_charge_boost_floor — the dynamically sized reserve that still has to
                 bridge the house to sunrise — both here and by clearing the flag outright (see
                 car_charger.morning_battery_boost_done), so midday solar refilling the pack
                 cannot re-arm the boost and force peak-tariff charging in the afternoon. #}
              {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
              {% set boost_floor = states('input_number.car_charge_boost_floor') | int(30) %}
              {% set morning_boost = is_state('input_boolean.car_charge_morning_boost', 'on') and battery > boost_floor %}
              {# House-pack rebalance: only block the car while it would actually
                 compete with it — at/near the knee (PV priority to the pack) or
                 mid grid-TOU charge (shares the 15-min peak budget, see
                 docs/battery-grid-charge-to-100.md). A rebalance run can now span
                 several days of partial sun (pylontech.nix); the car should not
                 sit blocked through every overnight SoC dip in between. Cancel
                 automation.solar_battery_pylontech_rebalance_cancel to unblock
                 outright. #}
              {% set rebalance_active = is_state('input_boolean.solar_battery_rebalance_active', 'on') %}
              {% set rebalance_grid = is_state('input_boolean.solar_battery_rebalance_using_grid', 'on') %}
              {% set rebalance = rebalance_active and (battery >= 97 or rebalance_grid) %}
              {# Hard last-resort safeguard (electricity_capacity_critical, capacity_peaks.nix):
                 the quarter's cap is projected to be breached by non-car load alone AND the
                 battery has nothing left to give — the car's 6A tail throttle can't fix this, so
                 stop entirely rather than add to the overage. General, not car-specific, so it
                 applies uniformly like `rebalance` — including over low_soc, since a few minutes
                 without topping up a low car battery is a smaller cost than the tariff hit, and
                 charging resumes automatically the moment this clears. #}
              {% set capacity_critical = is_state('binary_sensor.electricity_capacity_critical', 'on') %}
              {{ override != 'off' and not rebalance and not capacity_critical and (low_soc or should_charge_offpeak or solar_eligible or force_on or morning_boost) }}
            '';
          }
        ];
      }
    ];

    "automation manual" = [

      # Start charging: triggered when offpeak charging is needed
      (
        ha.automation "system/car_charger.start"
          {
            triggers = [
              (ha.trigger.on "binary_sensor.system_car_charger_should_charge")
              (ha.trigger.on "binary_sensor.system_car_charger_solar_charge_eligible")
              (ha.trigger.state_to "input_select.car_charge_override" "on")
              (ha.trigger.state_to "input_select.car_charge_override" "battery drain")
              (ha.trigger.state_to "input_select.car_charge_override" "solar+grid boost")
              (ha.trigger.state_to "input_select.car_charge_override" "solar+grid 16a")
              (ha.trigger.state "sensor.system_house_pv_battery_soc")
              # Grid peak protection can turn switch.system_car_charger off mid-charge (via
              # car_charger.stop). Re-check every 10m and resume: the `should_charge` on +
              # switch off conditions below mean this only restarts an interrupted charge and is
              # a no-op while already charging or when charging genuinely shouldn't run.
              (ha.trigger.time_pattern_minutes "/10")
              (ha.trigger.on "binary_sensor.system_car_charger_vehicle_connected")
            ];
            conditions = [
              (ha.condition.on "binary_sensor.system_car_charger_should_charge")
              {
                condition = "template";
                value_template = ''
                  {% set solar_eligible = is_state('binary_sensor.system_car_charger_solar_charge_eligible', 'on') %}
                  {% set override = states('input_select.car_charge_override') in ['on', 'battery drain', 'solar+grid boost', 'solar+grid 16a'] %}
                  {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
                  {% if solar_eligible and not override %}
                    {{ battery >= 15 }}
                  {% else %}
                    true
                  {% endif %}
                '';
              }
              (ha.condition.off "switch.system_car_charger")
              # The charger isn't actually connected to anything unless a car is plugged in —
              # without this, should_charge (which knows nothing about the physical connection)
              # kept firing start every ~10m / on every battery_soc tick while the car was away,
              # and the unplugged EVSE self-tripped back off within seconds each time (36 switch
              # flaps + 34 current writes observed in one 2h15m window on 2026-08-29).
              (ha.condition.on "binary_sensor.system_car_charger_vehicle_connected")
              # Never start charging during a fire alarm. The fire automation cuts the
              # charger as a large load; without this, should_charge would start it
              # straight back up. See smarthome/air_quality/fire_alarm.nix and
              # docs/fire-alarms.md.
              (ha.condition.off "input_boolean.fire_alarm_active")
            ];
            actions = [
              # Ensure charger switch is on
              (ha.action.on "switch.system_car_charger")
              # Reset the ramp baseline to 8A on every start, no matter what current was last set
              # (a stalled ramp, a leftover manual override, a prior self-trip). A cold start at
              # 13-16A is unreliable on this Andalung portable charger; done after turning the
              # switch on, since writing to it while off is known to flip the switch back on.
              (ha.action.set_value "number.system_car_charger_charging_current" 8)
              (ha.action.delay "00:00:15")
              # Gradually ramp current to target
              {
                service = "automation.trigger";
                target.entity_id = "automation.system_car_charger_set_current";
              }
              (ha.action.delay "00:00:10")
              # Set to immediate charging
              (ha.action.set_value "select.system_car_charger_charging_mode" "immediate")
              (ha.action.delay "00:00:10")
              (ha.action.on "switch.system_car_charger")
              (ha.action.delay "00:00:15")
            ];
          }
      )




      # Set current automation (combines update and set)
      (
        ha.automation "system/car_charger.set_current"
          {
            triggers = [
              # `for` debounces a noisy target: with `mode = restart`, every retrigger cancels the
              # in-flight step delay below and fires an immediate number.set_value. On 2026-08-29 a
              # fast-moving headroom estimate flapped the target 13->10->8->6A in ~2s, which sent
              # three step-down commands to the charger within that same window and it tripped
              # (E5/SuspendedEVSE) 3s later. Only react once the target has held for 30 seconds
              # (was 1 minute; shortened 2026-10-11 so the car backs off sooner towards the peak.
              # The flap that tripped E5 lasted ~2s, so 30s still sits far outside it).
              #
              # This debounce is specifically for the noisy front-of-quarter headroom branch
              # (already flagged there as chattery by design). The real capacity-tariff safety
              # drop gets its own undebounced trigger below, since it can't flap and shouldn't
              # wait.
              (ha.trigger.state_for "sensor.system_car_charger_target_current" "00:00:30")
              # Capacity-tariff safety drop: react the instant this arms, no debounce.
              # binary_sensor.system_car_charger_capacity_near is monotonic within a quarter (see
              # its definition), so — unlike the headroom branch above — it can't flap and there's
              # nothing to debounce against. It still needs the delay between steps below to avoid
              # retripping the charger, but reaching the 6A floor a full debounce cycle sooner
              # matters here: it's racing the quarter's 15-minute averaging window.
              (ha.trigger.on "binary_sensor.system_car_charger_capacity_near")
            ];
            conditions = [
              (ha.condition.on "switch.system_car_charger")
            ];
            mode = "restart";
            actions = [
              {
                repeat = {
                  while = [
                    {
                      condition = "template";
                      value_template = ''
                        {% set current = states('number.system_car_charger_charging_current') | int(6) %}
                        {% set target = states('sensor.system_car_charger_target_current') | int(12) %}
                        {{ current != target }}
                      '';
                    }
                  ];
                  sequence = [
                    {
                      service = "number.set_value";
                      target.entity_id = "number.system_car_charger_charging_current";
                      data.value = ''
                        {% set steps = [6, 8, 10, 13, 16] %}
                        {% set current = states('number.system_car_charger_charging_current') | int(6) %}
                        {% set target = states('sensor.system_car_charger_target_current') | int(6) %}
                        {% if target > current %}
                          {% set ns = namespace(val=target) %}
                          {% for s in steps %}
                            {% if s > current and s < ns.val %}
                              {% set ns.val = s %}
                            {% endif %}
                          {% endfor %}
                          {{ ns.val }}
                        {% elif target < current %}
                          {% set ns = namespace(val=target) %}
                          {% for s in steps | reverse %}
                            {% if s < current and s > ns.val %}
                              {% set ns.val = s %}
                            {% endif %}
                          {% endfor %}
                          {{ ns.val }}
                        {% else %}
                          {{ current }}
                        {% endif %}
                      '';
                    }
                    # One step per 45s. Faster than this retrips the charger (E5, 2026-08-29:
                    # three steps in ~2s). 13 -> 6 is three steps, so the floor is reached
                    # after two waits, ~90s. capacity_near above is undebounced on purpose.
                    (ha.action.delay "00:00:45")
                  ];
                };
              }
            ];
          }
      )

      

      # Ensure charger is off when not needed
      (
        ha.automation "system/car_charger.stop"
          {
            triggers = [
              (ha.trigger.on "switch.system_car_charger")
              (ha.trigger.on "binary_sensor.car_charger_charging")
              (ha.trigger.off "binary_sensor.system_car_charger_should_charge")
              (ha.trigger.time_pattern_minutes "/10")
            ];
            conditions = [
              (ha.condition.off "binary_sensor.system_car_charger_should_charge")
              # Odd bug, if you call this while off, it puts it on.
              (ha.condition.on "switch.system_car_charger")
            ];
            actions = [
              (ha.action.off "switch.system_car_charger")
              (ha.action.delay "00:00:05")
              (ha.action.set_value "number.system_car_charger_timer" 6)
              (ha.action.delay "00:00:05")
              (ha.action.set_value "select.system_car_charger_charging_mode" "delayed_charge")
            ];
          }
      )

      # Stop and reset the ramp baseline when the car is physically unplugged mid-charge.
      # should_charge/stop above know nothing about the physical connection, so without this an
      # unplug while switch is on left the charger sitting on with no vehicle attached until the
      # next /10m recheck.
      (
        ha.automation "system/car_charger.disconnected"
          {
            triggers = [
              (ha.trigger.off "binary_sensor.system_car_charger_vehicle_connected")
            ];
            conditions = [
              # Odd bug, if you call this while off, it puts it on — only touch the device if we
              # know it's actually on right now.
              (ha.condition.on "switch.system_car_charger")
            ];
            actions = [
              (ha.action.off "switch.system_car_charger")
              (ha.action.delay "00:00:05")
              (ha.action.set_value "number.system_car_charger_charging_current" 8)
            ];
          }
      )

      # Notify (if someone is home):
      #  - 21:50 if the charge override is off (charger won't start tonight)
      #  - 21:55 if either override (charge or current) is not on auto (won't follow the schedule)
      (
        ha.automation "system/car_charger.notify_override_off"
          {
            triggers = [
              { platform = "time"; at = "21:50:00"; id = "off_2150"; }
              { platform = "time"; at = "21:55:00"; id = "notauto_2155"; }
            ];
            conditions = [
              (ha.condition.on "binary_sensor.anyone_home")
            ];
            actions = [
              {
                choose = [
                  {
                    conditions = [
                      { condition = "trigger"; id = "off_2150"; }
                      {
                        condition = "state";
                        entity_id = "input_select.car_charge_override";
                        state = "off";
                      }
                    ];
                    sequence = [
                      {
                        service = "notify.mobile_app_nphone_p10pro";
                        data = {
                          title = "Car charger";
                          message = "Override is set to off — charger will not start tonight.";
                          data.actions = [
                            {
                              action = "car_charger_override_auto";
                              title = "Set to auto";
                            }
                          ];
                        };
                      }
                    ];
                  }
                  {
                    conditions = [
                      { condition = "trigger"; id = "notauto_2155"; }
                      {
                        condition = "template";
                        value_template = ''
                          {{ not is_state('input_select.car_charge_override', 'auto')
                             or not is_state('input_select.system_car_charger_current_override_a', 'auto') }}
                        '';
                      }
                    ];
                    sequence = [
                      {
                        service = "notify.mobile_app_nphone_p10pro";
                        data = {
                          title = "Car charger";
                          message = ''
                            Charger is not on auto — charge: {{ states('input_select.car_charge_override') }}, current: {{ states('input_select.system_car_charger_current_override_a') }}. It won't follow the schedule tonight.
                          '';
                          data.actions = [
                            {
                              action = "car_charger_override_auto";
                              title = "Set both to auto";
                            }
                          ];
                        };
                      }
                    ];
                  }
                ];
              }
            ];
          }
      )

      # Handle actionable notification: set both overrides back to auto
      (
        ha.automation "system/car_charger.notify_override_off.handle_action"
          {
            triggers = [
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charger_override_auto";
              }
            ];
            conditions = [ ];
            actions = [
              (ha.action.set_value "input_select.car_charge_override" "auto")
              (ha.action.set_value "input_select.system_car_charger_current_override_a" "auto")
            ];
          }
      )

      # "auto + battery" mode: revert to normal auto once the home battery is full enough.
      (
        ha.automation "system/car_charger.battery_mode_auto_revert"
          {
            triggers = [
              (ha.trigger.state "sensor.system_house_pv_battery_soc")
            ];
            conditions = [
              {
                condition = "state";
                entity_id = "input_select.car_charge_override";
                state = "auto + battery";
              }
              {
                condition = "template";
                value_template = ''
                  {{ states('sensor.system_house_pv_battery_soc') | int(0) >= 80 }}
                '';
              }
            ];
            actions = [
              (ha.action.set_value "input_select.car_charge_override" "auto")
            ];
          }
      )

      # Morning battery boost. On a good solar day the pack will be refilled (and would
      # otherwise clip and export at the low injection price), so anything it still holds
      # before sunrise is worth more in the car than in the pack.
      #
      # Runs every 15 min from 05:00. Two jobs, in order:
      #
      #   1. Recompute input_number.car_charge_boost_floor from the HOURLY solar forecast --
      #      how much SoC must stay in the pack to carry the house on its own until the sun
      #      out-produces the baseload. This is the whole point: drain as deep as the day
      #      allows, but never so deep that the house falls back on the grid at 07:00. A dull
      #      morning pushes the crossover later, the deficit up and the floor with it; a bright
      #      one lets the boost run the pack down close to the inverter's own cut-off.
      #      Recomputed on every tick, so a forecast that degrades mid-boost raises the floor
      #      and stops the charge early rather than overshooting.
      #
      #   2. Arm the boost, if the window and the gates allow.
      #
      # Re-evaluated rather than decided once at 05:00: the pack falls ~2-3%/h overnight, so a
      # single 05:00 snapshot samples the window at its lowest point and a battery a few %
      # under the gate loses the whole morning (2026-09-10: 46% at 05:00 vs a 50% gate, car
      # plugged in at 57% until 07:44 -- boost skipped, and it had not fired since 2026-08-08).
      (
        ha.automation "system/car_charger.morning_battery_boost"
          {
            triggers = [
              (ha.trigger.time_pattern_minutes "/15")
            ];
            conditions = [
              # Keep maintaining the floor past the arming window so a running boost stops on a
              # current number; 09:00 matches morning_battery_boost_done's backstop.
              { condition = "time"; after = "05:00:00"; before = "09:00:00"; }
              # Respect manual overrides
              {
                condition = "state";
                entity_id = "input_select.car_charge_override";
                state = "auto";
              }
            ];
            actions = [
              # Hourly resolution: `watts` is the mean power forecast per hour, which is what
              # the baseload has to be compared against. config_entry_id() avoids pinning the
              # integration's opaque entry id into the config.
              {
                service = "forecast_solar.get_forecast";
                data = {
                  config_entry = "{{ config_entry_id('sensor.energy_production_today_remaining') }}";
                  resolution = "hourly";
                };
                response_variable = "solar_fc";
              }
              (ha.action.set_value "input_number.car_charge_boost_floor" ''
                {# Walk today's remaining hours until forecast power covers the house, summing
                   the shortfall the pack has to cover in the meantime. #}
                {% set baseload = states('sensor.electricity_house_baseload_power_mean_60m') | float(300) %}
                {# The 60-min mean is sampled pre-dawn on a sleeping house, so it understates the
                   07:00-09:00 wake-up ramp; uplift rather than trust it flat. 300W is a floor
                   for a cold-start mean that has not filled yet. #}
                {% set need = [baseload, 300] | max * 1.3 %}
                {% set ns = namespace(deficit = 0.0, covered = false) %}
                {% for slot, watts in (solar_fc['watts'] | default({}, true)) | dictsort %}
                  {% set t = as_datetime(slot) | as_local %}
                  {% if not ns.covered and t.date() == now().date()
                        and t >= now().replace(minute=0, second=0, microsecond=0) %}
                    {% if (watts | float(0)) >= need %}
                      {% set ns.covered = true %}
                    {% else %}
                      {# The hour we are standing in only counts for the part still ahead. #}
                      {% set frac = ((60 - now().minute) / 60) if t.hour == now().hour else 1.0 %}
                      {% set ns.deficit = ns.deficit + (need - (watts | float(0))) * frac %}
                    {% endif %}
                  {% endif %}
                {% endfor %}
                {# 83 Wh per SoC point: US5000 (48) + US3000C (35), same constant as
                   solar/battery/charging/remaining_minutes_till_overdischargesoc. #}
                {% set reserve = (ns.deficit / 83) | round(0, 'ceil') | int %}
                {# The inverter stops discharging at number.system_house_pv_overdischarge_soc
                   (15% while there is solar left today; see smarthome/energy/solar/battery.nix)
                   -- below that the house, and the car, silently switch to the grid, which is
                   exactly what this is meant to avoid. That SoC is therefore NOT available to
                   bridge the morning: the reserve has to sit ON TOP of it. Read live rather than
                   hard-coded, so retuning that floor (to 12%, say) automatically retunes how deep
                   the boost may drain. #}
                {% set inverter_floor = states('number.system_house_pv_overdischarge_soc') | int(15) %}
                {# Stop the car here: inverter cut-off + what the house still has to draw before
                   the sun takes over + 2 points of slack for forecast error and for the lag in
                   the SoC sensor the car stops on (aiming exactly would let the inverter cut out
                   from under a still-drawing charger).
                   If the forecast never covers the baseload today, `covered` stays false and the
                   deficit runs to the end of the day -- the floor lands high and the boost simply
                   never arms. That is the correct answer for a dull day. #}
                {{ [ inverter_floor + reserve + 2, 60 ] | min }}
              '')
              (ha.action.conditional
                [
                  # Arming window proper. Past 07:00 the sun is taking over and the car should
                  # be on solar, not on the pack.
                  { condition = "time"; after = "05:00:00"; before = "07:00:00"; }
                  # Don't re-arm within the same morning after the floor cleared it.
                  (ha.condition.off "input_boolean.car_charge_morning_boost")
                  # Only worthwhile on a good solar day -- the pack has to be confident of being
                  # refilled before we empty it into the car.
                  {
                    condition = "template";
                    value_template = ''
                      {{ states('sensor.energy_production_today_remaining') | float(0) >= 9 }}
                    '';
                  }
                  # Enough above the floor to be worth starting: 8 points is ~0.66 kWh, roughly
                  # 13 min at 13A. Below that the boost would arm for almost no transfer.
                  {
                    condition = "template";
                    value_template = ''
                      {% set battery = states('sensor.system_house_pv_battery_soc') | int(0) %}
                      {% set floor = states('input_number.car_charge_boost_floor') | int(60) %}
                      {{ battery >= floor + 8 }}
                    '';
                  }
                  # Pointless unless a car is actually attached with room to take the charge.
                  (ha.condition.on "binary_sensor.system_car_charger_vehicle_connected")
                  {
                    condition = "template";
                    value_template = ''
                      {{ states('sensor.audi_a6_sportback_e_tron_state_of_charge') | float(100) < 90 }}
                    '';
                  }
                ]
                [ (ha.action.on "input_boolean.car_charge_morning_boost") ]
                [ ]
              )
            ];
          }
      )

      # Clear morning_boost once it has done its job. Without this the flag stays on until
      # 21:00, and should_charge's `battery > floor` gate goes true again the moment midday
      # solar refills the pack -- forcing the car on through peak hours with no solar or tariff
      # check. Clear at the floor, and at 09:00 as a backstop if the pack never got there (car
      # unplugged early, boost never actually drew).
      (
        ha.automation "system/car_charger.morning_battery_boost_done"
          {
            triggers = [
              (ha.trigger.template_for ''
                {% set battery = states('sensor.system_house_pv_battery_soc') | int(100) %}
                {% set floor = states('input_number.car_charge_boost_floor') | int(30) %}
                {{ is_state('input_boolean.car_charge_morning_boost', 'on') and battery <= floor }}
              '' "00:03:00")
              { platform = "time"; at = "09:00:00"; }
            ];
            conditions = [
              (ha.condition.on "input_boolean.car_charge_morning_boost")
            ];
            actions = [
              (ha.action.off "input_boolean.car_charge_morning_boost")
            ];
          }
      )

      # "battery drain" mode: notify when the house battery hits 20% (phase 1 → phase 2).
      # No override change needed — the should_charge and target_current templates automatically
      # switch to solar-only once battery_drain_force becomes false at the 20% floor.
      (
        ha.automation "system/car_charger.battery_drain_phase_transition"
          {
            triggers = [
              (ha.trigger.state "sensor.system_house_pv_battery_soc")
            ];
            conditions = [
              {
                condition = "state";
                entity_id = "input_select.car_charge_override";
                state = "battery drain";
              }
              {
                condition = "template";
                value_template = ''
                  {{ states('sensor.system_house_pv_battery_soc') | int(100) <= 20 }}
                '';
              }
            ];
            actions = [
              {
                service = "notify.mobile_app_nphone_p10pro";
                data = {
                  title = "Car charger";
                  message = "House battery at {{ states('sensor.system_house_pv_battery_soc') }}% — switching to solar-only charging.";
                  data.actions = [
                    {
                      action = "car_charger_override_auto";
                      title = "Set to auto";
                    }
                  ];
                };
              }
            ];
          }
      )

      # 21:00 — plan tomorrow's charge. Reset the grid ceiling to the 70% default, work out
      # whether tomorrow will be sunny (conservative solar forecast + weather.sxw condition),
      # then ask (actionable notification) how the car will be used. No answer keeps the safe
      # 70% default. See handle_action below.
      (
        ha.automation "system/car_charger.plan_tomorrow"
          {
            triggers = [
              { platform = "time"; at = "21:00:00"; }
            ];
            conditions = [ ];
            actions = [
              # Reset to the default before (re)asking, so an unanswered night lands on 70%
              # and yesterday's choice never lingers.
              (ha.action.set_value "input_number.car_charge_grid_target" 70)
              # Clear morning boost so it re-evaluates fresh at 05:00 tomorrow.
              (ha.action.off "input_boolean.car_charge_morning_boost")
              # Pull tomorrow's forecast (weather.sxw supports daily forecasts).
              {
                service = "weather.get_forecasts";
                target.entity_id = "weather.sxw";
                data.type = "daily";
                response_variable = "fc";
              }
              # Store the sunny assessment for the notification message.
              (ha.action.conditional
                [
                  (ha.condition.template ''
                    {% set t = (now() + timedelta(days=1)).date() %}
                    {% set ns = namespace(cond='unknown') %}
                    {% for f in fc['weather.sxw'].forecast %}
                      {% if as_datetime(f.datetime).date() == t %}{% set ns.cond = f.condition %}{% endif %}
                    {% endfor %}
                    {# energy_production_tomorrow always underestimates, so a moderate figure
                       already means a good day; treat as sunny when the sky is clear-ish OR the
                       conservative forecast is high on its own. #}
                    {% set prod = states('sensor.energy_production_tomorrow') | float(0) %}
                    {% set clear = ns.cond in ['sunny', 'partlycloudy', 'clear-night', 'windy-variant'] %}
                    {{ (clear and prod >= 6) or prod >= 10 }}
                  '')
                ]
                [ (ha.action.on "input_boolean.car_charge_sunny_tomorrow") ]
                [ (ha.action.off "input_boolean.car_charge_sunny_tomorrow") ])
              {
                service = "notify.mobile_app_nphone_p10pro";
                data = {
                  title = "Car charge plan for tomorrow";
                  message = ''
                    Solar forecast ~{{ states('sensor.energy_production_tomorrow') | float(0) | round(0) }} kWh (min). {% if is_state('input_boolean.car_charge_sunny_tomorrow', 'on') %}☀️ Sunny.{% else %}☁️ Dull.{% endif %}
                    "Stay home" 50% (solar tops up) · "2 days driving" 70% · "Long drive" 100%.
                  '';
                  data = {
                    tag = "car_charge_plan";
                    actions = [
                      { action = "car_charge_plan_stay_home"; title = "🏠 Stay home"; }
                      { action = "car_charge_plan_drive_2days"; title = "🚗 2 days driving"; }
                      { action = "car_charge_plan_long_drive"; title = "🛣️ Long drive"; }
                    ];
                  };
                };
              }
            ];
          }
      )

      # Handle the plan_tomorrow reply: set the overnight grid ceiling and make sure charging
      # will actually run (override back to auto). Confirm back on the same notification tag.
      (
        ha.automation "system/car_charger.plan_tomorrow.handle_action"
          {
            triggers = [
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charge_plan_stay_home";
                id = "stay_home";
              }
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charge_plan_drive_2days";
                id = "drive_2days";
              }
              {
                platform = "event";
                event_type = "mobile_app_notification_action";
                event_data.action = "car_charge_plan_long_drive";
                id = "long_drive";
              }
            ];
            conditions = [ ];
            actions = [
              # An explicit plan implies I want charging tonight — clear a lingering "off".
              (ha.action.set_value "input_select.car_charge_override" "auto")
              {
                choose = [
                  # Stay home: grid guarantees 50%, solar tops up the rest during the day.
                  {
                    conditions = [ { condition = "trigger"; id = "stay_home"; } ];
                    sequence = [
                      (ha.action.set_value "input_number.car_charge_grid_target" 50)
                    ];
                  }
                  # 2 days driving: need reliable range, grid to 70%.
                  {
                    conditions = [ { condition = "trigger"; id = "drive_2days"; } ];
                    sequence = [
                      (ha.action.set_value "input_number.car_charge_grid_target" 70)
                    ];
                  }
                  # Long drive: fill from the grid overnight.
                  {
                    conditions = [ { condition = "trigger"; id = "long_drive"; } ];
                    sequence = [
                      (ha.action.set_value "input_number.car_charge_grid_target" 100)
                    ];
                  }
                ];
              }
              {
                service = "notify.mobile_app_nphone_p10pro";
                data = {
                  title = "Car charge plan for tomorrow";
                  message = ''
                    Grid-charging to {{ states('input_number.car_charge_grid_target') | float(70) | round(0) }}% tonight.
                  '';
                  data.tag = "car_charge_plan";
                };
              }
            ];
          }
      )

    ];

  };
}