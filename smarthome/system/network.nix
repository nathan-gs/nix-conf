# Derived sensors for the Network view of the "Server health" dashboard
# (smarthome/dashboards/server-health.yaml), for the one device on it that this
# flake does not publish: the Technicolor CGA modem. That integration is a UI
# config entry, so its sensors cannot be shaped at the source the way
# services/blocky.nix and services/wireguard2mqtt.nix shape theirs.
#
# The modem reports its WAN totals as raw byte counters, and a card shows a
# sensor's own unit — so a tile renders "870163456 B". The entities card's
# `format:` option only covers timestamps (relative/total/date/time/datetime),
# and there is no byte-scaling equivalent, so the only way to get a readable
# tile is a sensor that is already in the unit you want to read.
#
# Hence these two: same numbers, scaled to GB, with device_class data_size so
# HA still offers per-entity unit conversion in the UI. The dashboard points at
# these; the integration's own byte entities stay untouched and exact.
{ config, lib, pkgs, ... }:
let
  # The modem entity ids genuinely repeat the prefix: the integration slugifies
  # its device name, which is itself the topic-shaped
  # "system/network/router/orange". See the note in the dashboard.
  wanRx = "sensor.system_network_system_network_router_orange_wan_bytes_received";
  wanTx = "sensor.system_network_system_network_router_orange_wan_bytes_sent";

  # Guarded on the source being a real number. The modem drops its single
  # session every few hours and its sensors go unavailable until the
  # integration re-logs in, so an unguarded `| float / 1e9` would publish 0.0
  # across every gap and put a false flat line in the statistics. Returning
  # nothing at all makes these unavailable exactly when the source is, which is
  # the truthful answer.
  scaleToGb = source: ''
    {% set v = states('${source}') %}
    {% if v not in ['unknown', 'unavailable', 'none', none] and v | float(-1) >= 0 %}
      {{ (v | float(0) / 1000000000) | round(3) }}
    {% endif %}
  '';
in
{
  services.home-assistant.config = {
    template = [
      {
        sensor = [
          {
            name = "system/network/router/orange.wan_received_gb";
            unique_id = "system_network_router_orange_wan_received_gb";
            unit_of_measurement = "GB";
            device_class = "data_size";
            # The modem's own counters reset when it reboots, so this is a
            # total_increasing for the same reason the WireGuard peer counters
            # are — not a monotonic lifetime total.
            state_class = "total_increasing";
            icon = "mdi:download";
            state = scaleToGb wanRx;
          }
          {
            name = "system/network/router/orange.wan_sent_gb";
            unique_id = "system_network_router_orange_wan_sent_gb";
            unit_of_measurement = "GB";
            device_class = "data_size";
            state_class = "total_increasing";
            icon = "mdi:upload";
            state = scaleToGb wanTx;
          }
        ];
      }
    ];
  };
}
