{ config, pkgs, lib, ha, ... }:
let
  # -- ENGIE Empower Vast ----------------------------------------------------
  # Current contract, replacing Engie Drive. Prijsfiche "Vaste prijzen voor
  # contracten afgesloten in Augustus 2026, onbepaalde duur", contract version
  # 10/08/2026, supply from 2026-10-01. Price is guaranteed for at least one
  # year and may be revised yearly (ENGIE notifies 2 months ahead) -- when that
  # letter arrives, update the numbers here.
  #
  # Entity names still say `engie_drive`: renaming them would cost the input
  # helpers their history and their place on the dashboards, and they have
  # always meant "whatever the current ENGIE contract charges".
  #
  # All c(euro)/kWh incl. 6% BTW, except the injection price, which is not
  # VAT-liable. These are the *energy component* only -- grid fees, green
  # energy/WKK and accijns are added by the sensors below.
  engie = {
    # Tweevoudige meter (day/night registers), Vlaams Gewest.
    electricityPeak = 18.765;     # piekuren
    electricityOffpeak = 13.384;  # daluren -- "extra laag daltarief"
    gas = 6.576;
    # Injection is paid at the same rate on every register (piek/dal/nacht).
    injectionPeak = 3.190;
    injectionOffpeak = 3.190;
    # Vaste vergoeding, EUR/year. Charged pro rata the actual supply days, and
    # only once for a customer who both draws and injects -- so this single
    # 90 EUR also covers the injection contract.
    electricityFixedYear = 90.00;
    gasFixedYear = 60.00;
  };

  # Both welkomstvoordelen run for the first contract year, 2026-10-01 ..
  # 2027-09-30. That window is month-aligned, which is what lets the one-off
  # credits below amortise as an exact 1/12 per month.
  welcomeUntil = "2027-10-01";

  # Welkomstvoordeel, per kWh: a cut on the energy component only, explicitly
  # excluding the vaste vergoeding and the groene stroom/WKK cost. c(euro)/kWh.
  # Kept out of the input helpers so those keep showing the contract list
  # price; the sensors below drop it by themselves once it lapses.
  welcome = {
    electricity = 2.60;
    gas = 1.20;
  };

  # Welkomstvoordeel, one-off: a credit on the first-year invoices, EUR incl.
  # 6% BTW. It buys down the standing charge rather than the energy price, so
  # it is prorated into the *fixed* cost -- 1/12 per month off
  # `*_cost_monthly_fixed`, which carries it through `*_cost_daily_fixed` into
  # the `*_fixed_cost_total` the Energy dashboard accrues. Spreading it beats
  # dropping it on one month: the fixed/variable split we track stays
  # comparable month to month, and the accrued total never has to step
  # backwards (`total_increasing` would read that as a meter reset).
  welcomeCredit = {
    electricity = 45.00;
    gas = 60.00;
  };

  # Jinja expression: the welcome discount in EUR/kWh, 0 once it has lapsed.
  welcomeDiscount = c: ''
    (${toString c} / 100 if now() < as_local(as_datetime('${welcomeUntil}')) else 0)'';

  # Jinja expression: this month's share of the one-off credit, 0 once lapsed.
  welcomeCreditMonthly = c: ''
    (${toString c} / 12 if now() < as_local(as_datetime('${welcomeUntil}')) else 0)'';
in
{

  # https://try.jsoup.org/

  services.home-assistant.config = {

    # `initial` is what makes the repo -- rather than whatever was last typed
    # into the UI -- the source of truth for the contract price: HA forces it on
    # every restart instead of restoring the previous state. The CREG injection
    # rate below has no `initial`: it is a regulated figure that changes on its
    # own schedule and is maintained by hand.
    input_number = {
      gas_cost_engie_drive_kwh_energycomponent = {
        initial = engie.gas / 100;
        step = 0.001;
        min = 0;
        max = 2;
        unit_of_measurement = "€/kWh";
        mode = "box";
      };
      electricity_cost_engie_drive_peak_kwh_energycomponent = {
        initial = engie.electricityPeak / 100;
        step = 0.001;
        min = 0;
        max = 2;
        unit_of_measurement = "€/kWh";
        mode = "box";
      };
      electricity_cost_engie_drive_offpeak_kwh_energycomponent = {
        initial = engie.electricityOffpeak / 100;
        step = 0.001;
        min = 0;
        max = 2;
        unit_of_measurement = "€/kWh";
        mode = "box";
      };
      electricity_injection_engie_drive_peak_kwh = {
        initial = engie.injectionPeak / 100;
        step = 0.001;
        min = 0;
        max = 2;
        unit_of_measurement = "€/kWh";
        mode = "box";
      };
      electricity_injection_engie_drive_offpeak_kwh = {
        initial = engie.injectionOffpeak / 100;
        step = 0.001;
        min = 0;
        max = 2;
        unit_of_measurement = "€/kWh";
        mode = "box";
      };
      electricity_injection_creg_kwh = {
        step = 0.001;
        min = 0;
        max = 2;
        unit_of_measurement = "€/kWh";
        mode = "box";
      };
    };

    template = [  
      {
        sensor = [
          {
            name = "gas_cost_kwh";
            unique_id = "gas_cost_kwh";
            unit_of_measurement = "€/kWh";
            # Fluvius Imewo 2026 net + federal (post 2026-08-01). All c€/€ incl. 6% BTW.
            # VNR: FI ELEK/GAS 2026; federal accijns reform abolishes energiebijdrage from Aug 2026.
            state = ''
              {% set energycomponent = (states('input_number.gas_cost_engie_drive_kwh_energycomponent') | float) - ${welcomeDiscount welcome.gas} %}
              {% set gas_yearly = (states('sensor.gas_delivery_yearly') | float * 11.5822997166)  %}
              {# Imewo prop. term T2 (>=5001 kWh) / T1 (0-5000), incl. ODV+toeslagen, incl. BTW #}
              {% set imewo = (1.02399 / 100) %}
              {% if gas_yearly < 5000 %}
                {% set imewo = (2.62774 / 100) %}
              {% endif %}
              {# Fluxys transport ~1.56 €/MWh excl. → ~0.165 c€/kWh incl. BTW #}
              {% set transport = (0.165 / 100) %}
              {# Energiebijdrage abolished 2026-08-01 #}
              {% set energiebijdrage = 0 %}
              {# Bijzondere accijns incl. BTW: >12 MWh / 0-12 MWh (from 2026-08-01) #}
              {% set accijns = (1.183 / 100) %}
              {% if gas_yearly < 12000 %}
                {% set accijns = (1.093 / 100) %}
              {% endif %}
              {{ (energycomponent + imewo + transport + energiebijdrage + accijns) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            name = "gas_cost_m3";
            unique_id = "gas_cost_m3";
            unit_of_measurement = "€/m³";
            state = "{{ ( states('sensor.gas_cost_kwh') | float ) * 11.5822997166}}";
            state_class = "measurement";
          }
          {
            name = "gas_cost_monthly_fixed";
            unique_id = "gas_cost_monthly_fixed";
            unit_of_measurement = "€";
            state = ''
              {% set gas_yearly = (states('sensor.gas_delivery_yearly') | float * 11.5822997166)  %}
              {% set engie = ${toString engie.gasFixedYear} %}
              {# Imewo vaste term T2 / T1, incl. BTW #}
              {% set imewo = 98.81 %}
              {% if gas_yearly < 5000 %}
                {% set imewo = 18.61 %}
              {% endif %}
              {% set databeheer = 18.92 %}
              {% set welcome_credit = ${welcomeCreditMonthly welcomeCredit.gas} %}
              {{ ((engie / 12) + (imewo / 12) + (databeheer / 12) - welcome_credit) | round(5) }}
            '';
            state_class = "measurement";
          }           
          {
            name = "electricity_cost_peak_kwh";
            unique_id = "electricity_cost_peak_kwh";
            unit_of_measurement = "€/kWh";
            state = ''
              {% set energycomponent = (states('input_number.electricity_cost_engie_drive_peak_kwh_energycomponent') | float) - ${welcomeDiscount welcome.electricity} %}
              {% set wkk_and_greenenergy = (1.582 / 100) %}
              {# Imewo LS piekmeting: netgebruik + ODV + toeslagen, incl. BTW (same peak/offpeak) #}
              {% set imewo = (5.54236 / 100) %}
              {# Energiebijdrage abolished 2026-08-01 #}
              {% set energiebijdrage = 0 %}
              {# Bijzondere accijns 48.76 €/MWh incl. BTW (from 2026-08-01) #}
              {% set accijns = (4.876 / 100) %}
              {{ (energycomponent + wkk_and_greenenergy + imewo + energiebijdrage + accijns) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            name = "electricity_cost_offpeak_kwh";
            unique_id = "electricity_cost_offpeak_kwh";
            unit_of_measurement = "€/kWh";            
            state = ''
              {% set energycomponent = (states('input_number.electricity_cost_engie_drive_offpeak_kwh_energycomponent') | float) - ${welcomeDiscount welcome.electricity} %}
              {% set wkk_and_greenenergy = (1.582 / 100) %}
              {% set imewo = (5.54236 / 100) %}
              {% set energiebijdrage = 0 %}
              {% set accijns = (4.876 / 100) %}
              {{ (energycomponent + wkk_and_greenenergy + imewo + energiebijdrage + accijns) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            name = "electricity_cost_monthly_fixed";
            unique_id = "electricity_cost_monthly_fixed";
            unit_of_measurement = "€";
            state = ''
              {% set engie = ${toString engie.electricityFixedYear} %}
              {# Imewo capaciteitstarief 2026 €/kW/year incl. BTW; billed monthly as 1/12.
                 Billable kW = avg of last 12 monthly peaks (each floored at 2.5 kW). #}
              {% set imewo_capacitytariffs_per_kw_year = 57.453 %}
              {% set capacity_kw = states('sensor.electricity_capacity_peak_12months') | float(2.5) %}
              {% set databeheer = 18.92 %}
              {% set welcome_credit = ${welcomeCreditMonthly welcomeCredit.electricity} %}
              {{ ((engie / 12) + ((imewo_capacitytariffs_per_kw_year / 12) * capacity_kw) + (databeheer / 12) - welcome_credit) | round(5) }}
            '';
            state_class = "measurement";
          }
          {
            # Monthly fixed ÷ days-in-month — used to accrue into the Energy dashboard.
            name = "electricity_cost_daily_fixed";
            unique_id = "electricity_cost_daily_fixed";
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "measurement";
            icon = "mdi:calendar-today";
            state = ''
              {% set monthly = states('sensor.electricity_cost_monthly_fixed') | float(0) %}
              {% set last_day = (now().replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1) %}
              {{ (monthly / last_day.day) | round(5) }}
            '';
          }
          {
            name = "gas_cost_daily_fixed";
            unique_id = "gas_cost_daily_fixed";
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "measurement";
            icon = "mdi:calendar-today";
            state = ''
              {% set monthly = states('sensor.gas_cost_monthly_fixed') | float(0) %}
              {% set last_day = (now().replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1) %}
              {{ (monthly / last_day.day) | round(5) }}
            '';
          }
          {
            # Dummy 0 kWh / 0 m³ sources so the Energy dashboard can attach fixed-cost totals
            # (HA only accepts cost on an energy/gas statistic).
            name = "electricity_fixed_cost_energy";
            unique_id = "electricity_fixed_cost_energy";
            unit_of_measurement = "kWh";
            device_class = "energy";
            state_class = "total";
            icon = "mdi:cash-clock";
            state = "0";
          }
          {
            name = "gas_fixed_cost_volume";
            unique_id = "gas_fixed_cost_volume";
            unit_of_measurement = "m³";
            device_class = "gas";
            state_class = "total";
            icon = "mdi:cash-clock";
            state = "0";
          }
          {
            name = "electricity_injection_kwh";
            unique_id = "electricity_injection_kwh";
            unit_of_measurement = "€/kWh"; 
            state = ''
              {% if (states('binary_sensor.electricity_is_offpeak') | bool(false)) %}
                {{ states('input_number.electricity_injection_engie_drive_offpeak_kwh') | float }}
              {% else %}
                {{ states('input_number.electricity_injection_engie_drive_peak_kwh') | float }}
              {% endif %}
            '';
            state_class = "measurement";
          }
          {
            name = "electricity_injection_creg_kwh";
            unique_id = "electricity_injection_creg_kwh";
            unit_of_measurement = "€/kWh"; 
            state = ''
              {{ states('input_number.electricity_injection_creg_kwh') | float }}              
            '';
            state_class = "measurement";
          }
          {
            name = "energy/electricity/cost";
            unique_id = "energy_electricity_cost";
            unit_of_measurement = "€/kWh";
            state = ''
              {% if (states('binary_sensor.electricity_is_offpeak') | bool(false)) %}
                {{ states('sensor.electricity_cost_offpeak_kwh') | float }}
              {% else %}
                {{ states('sensor.electricity_cost_peak_kwh') | float }}
              {% endif %}
            '';
            state_class = "measurement";
          }          

        ];
        binary_sensor = [
          {
            name = "energy/electricity/prefer_over_gas";
            unique_id = "energy_electricity_prefer_over_gas";
            state = ''
              {% set electricity_cost = states('sensor.energy_electricity_cost') | float(10) %}
              {% set gas_cost = states('sensor.gas_cost_kwh') | float(0.15) %}
              {{ (electricity_cost / 4) < gas_cost }}
            '';            
          }
          {
            name = "electricity_is_offpeak";
            unique_id = "electricity_is_offpeak";
            state = ''
              {% set day = now().weekday() %}
              {% set hour = now().hour %}
              {% set is_weekend = day >= 5 %}
              {{ is_weekend or not(7 <= hour < 22) }}
            '';
          }
        ];
      }
      {
        trigger = [
          {
            platform = "time_pattern";
            hours = "23";
            minutes = "59";
            seconds = "50";
          }
        ];
        sensor = [
          {
            name = "electricity_injection_creg_kwh_previous";
            unique_id = "electricity_injection_creg_kwh_previous";
            unit_of_measurement = "€/kWh";
            state = ''
              {% set last_day = (now().replace(day=28) + timedelta(days=4)).replace(day=1) - timedelta(days=1) %}
              {% if now().day == last_day.day %}
                {{ states('sensor.electricity_injection_creg_kwh') | float(0) }}
              {% else %}
                {{ this.state | float(0) }}
              {% endif %}
            '';
            state_class = "measurement";
          }
        ];
      }
      # Accrue daily fixed costs into total_increasing monetary sensors for the Energy dashboard.
      # - 00:00: add today's daily fixed once (so the day already includes fixed cost)
      # - start / daily_fixed available: seed month-to-date (incl. today) if still 0
      #   (avoids startup race where start fired before daily_fixed existed)
      {
        trigger = [
          { platform = "time"; at = "00:00:00"; id = "accrue"; }
          {
            platform = "homeassistant";
            event = "start";
            id = "seed";
          }
          {
            platform = "state";
            entity_id = [
              "sensor.electricity_cost_daily_fixed"
              "sensor.gas_cost_daily_fixed"
            ];
            id = "seed";
          }
        ];
        sensor = [
          {
            name = "electricity_fixed_cost_total";
            unique_id = "electricity_fixed_cost_total";
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total_increasing";
            icon = "mdi:cash-clock";
            state = ''
              {% set daily = states('sensor.electricity_cost_daily_fixed') | float(0) %}
              {% set prev = this.state | float(0) if this.state not in ['unknown', 'unavailable', 'none'] else 0 %}
              {% if trigger.id == 'accrue' %}
                {{ (prev + daily) | round(5) }}
              {% elif prev == 0 and daily > 0 %}
                {{ (daily * now().day) | round(5) }}
              {% else %}
                {{ prev }}
              {% endif %}
            '';
          }
          {
            name = "gas_fixed_cost_total";
            unique_id = "gas_fixed_cost_total";
            unit_of_measurement = "€";
            device_class = "monetary";
            state_class = "total_increasing";
            icon = "mdi:cash-clock";
            state = ''
              {% set daily = states('sensor.gas_cost_daily_fixed') | float(0) %}
              {% set prev = this.state | float(0) if this.state not in ['unknown', 'unavailable', 'none'] else 0 %}
              {% if trigger.id == 'accrue' %}
                {{ (prev + daily) | round(5) }}
              {% elif prev == 0 and daily > 0 %}
                {{ (daily * now().day) | round(5) }}
              {% else %}
                {{ prev }}
              {% endif %}
            '';
          }
        ];
      }
    ];

    #scrape = [
      # {
      #   resource = "https://callmepower.be/nl/energie/leveranciers/octaplus/tarieven";
      #   scan_interval = 3600;
      #   sensor = [
      #     {
      #       name = "electricity_cost_octa_peak_kwh_energycomponent";
      #       select = "table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(Dagtarief)";
      #       value_template = "{{ (value.split('€')[1]|replace(',', '.')|trim | float) / 100 }}";
      #       unit_of_measurement = "€/kWh";
      #       state_class = "measurement";
      #     }
      #     {
      #       name = "electricity_cost_octa_offpeak_kwh_energycomponent";
      #       select = "table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(Nachttarief)";
      #       unit_of_measurement = "€/kWh";
      #       value_template = "{{ (value.split('€')[1]|replace(',', '.')|trim | float) / 100 }}";
      #       state_class = "measurement";
      #     }
      #     {
      #       name = "gas_cost_octa_kwh_energycomponent";
      #       select = ''
      #         h3#octa-clear-gas + p + p + div table:has(th:-soup-contains(Clear)) tbody td li:-soup-contains(cent)
      #       '';
      #       unit_of_measurement = "€/kWh";
      #       value_template = ''
      #         {{ (value.split(':')[1].split('€')[1]|replace(',', '.')|trim | float) / 100 }}
      #       '';
      #       state_class = "measurement";
      #     }
      #   ];
      # }
      # {
      #   resource = "https://callmepower.be/nl/energie/leveranciers/engie-electrabel/tarieven/drive";
      #   scan_interval = 3600;
      #   sensor = [
      #     {
      #       name = "electricity_cost_engie_drive_peak_kwh_energycomponent";
      #       # TODO Sept 2025 replace the discount
      #       select = ''
      #         h2#actuele-engie-drive-prijzen-per-kwh + p + p + div table tbody td li:-soup-contains(Dagtarief)
      #       '';
      #       value_template = ''
      #         {% set discount = 0 %}
      #         {% if now().year < 2025 and now().month < 10 %}
      #           {% set discount = 0.0293 %}
      #         {% endif %}
      #         {{ (((value.split('€')[1]|replace(',', '.')|trim | float) / 100) - discount) | round(5) }}
      #       '';
      #       unit_of_measurement = "€/kWh";
      #       state_class = "measurement";
      #     }
      #     {
      #       name = "electricity_cost_engie_drive_offpeak_kwh_energycomponent";
      #       # TODO Sept 2025 replace the discount
      #       select = ''
      #         h2#actuele-engie-drive-prijzen-per-kwh + p + p + div table tbody td li:-soup-contains(Nachttarief)
      #       '';
      #       unit_of_measurement = "€/kWh";
      #       value_template = 
      #       ''
      #         {% set discount = 0 %}
      #         {% if now().year < 2025 and now().month < 10 %}
      #           {% set discount = 0.0293 %}
      #         {% endif %}
      #         {{ (((value.split('€')[1]|replace(',', '.')|trim | float) / 100) - discount) | round(5) }}
      #       '';
      #       state_class = "measurement";
      #     }
      #     {
      #       name = "gas_cost_engie_drive_kwh_energycomponent";
      #       select = ''
      #         h3#gasprijs-engie-drive + p + p + div table:has(th:-soup-contains(Drive)) tbody td li:-soup-contains(cent)
      #       '';
      #       unit_of_measurement = "€/kWh";
      #       # TODO Sept 2025 replace the discount
      #       value_template = ''
      #         {% set discount = 0 %}
      #         {% if now().year < 2025 and now().month < 10 %}
      #           {% set discount = 0.0106 %}
      #         {% endif %}
      #         {{ (((value.split(':')[1].split('€')[1]|replace(',', '.')|trim | float) / 100) - discount) | round(5) }}
      #       '';
      #       state_class = "measurement";
      #     }
      #   ];
      # }
      # {
      #   resource = "https://www.mijnenergie.be/blog/injectietarieven/";
      #   scan_interval = 3600;
      #   sensor = [
      #     {
      #       name = "electricity_injection_octa_kwh";
      #       select = ''
      #         table :has(> td:-soup-contains(Octa)) td:nth-child(3)
      #       '' ;
      #       value_template = "{{ (value | replace(',', '.') | float(-1) / 100) | round(5) }}";
      #       unit_of_measurement = "€/kWh";
      #       state_class = "measurement";
      #     }
      #     {
      #       name = "electricity_injection_engie_drive_peak_kwh";
      #       select = ''
      #         table :has(> td:-soup-contains(Flow)) td:nth-child(4)
      #       '' ;
      #       value_template = "{{ (value | replace(',', '.') | float(-1) / 100) | round(5) }}";
      #       unit_of_measurement = "€/kWh";
      #       state_class = "measurement";
      #     }
      #     {
      #       name = "electricity_injection_engie_drive_offpeak_kwh";
      #       select = ''
      #         table :has(> td:-soup-contains(Flow)) td:nth-child(5)
      #       '' ;
      #       value_template = "{{ (value | replace(',', '.') | float(-1) / 100) | round(5) }}";
      #       unit_of_measurement = "€/kWh";
      #       state_class = "measurement";
      #     }
      #   ];
      # }
      # {
      #   resource = "https://www.pluginvest.eu/en/technische-hulp/creg-tarief-2025";
      #   scan_interval = 3600;
      #   sensor = [
      #     {
      #       name = "electricity_injection_creg_kwh";
      #       select = ''
      #         section.s_title h2 font.text-o-color-1 b
      #       '' ;
      #       value_template = ''{{ ((value | replace("€", "") | replace("/kWh", "") | replace(",", ".") | trim | float) * 1) | round(3) }}'';
      #       unit_of_measurement = "€/kWh";
      #       state_class = "measurement";
      #     }
      #   ];
      # }
    #];

    
  };
}
