{ lib, pkgs, ... }:

let
  # Existing sidebar URLs. YAML is registered before storage, and the matching
  # storage entries are removed below, so each dashboard exists once.
  dashboards = [
    { url = "dashboard-toestellen"; title = "Toestellen"; icon = "mdi:dishwasher"; file = "devices.yaml"; }
    { url = "lovelace-energy"; title = "Energy"; icon = "mdi:home-lightning-bolt"; file = "energy.yaml"; }
    { url = "dashboard-hvac"; title = "HVAC"; icon = "mdi:hvac"; file = "hvac.yaml"; }
    { url = "air-quality"; title = "Air Quality"; icon = "mdi:approximately-equal"; file = "air_quality.yaml"; }
    { url = "dashboard-maintenance"; title = "Maintenance"; icon = "mdi:wrench"; file = "maintenance.yaml"; }
    { url = "room-control"; title = "Room Control"; icon = "mdi:home"; file = "room_control.yaml"; }
  ];
in
{
  # Same install as server-health (smarthome/system/servers.nix): copy and
  # touch, so HA's mtime cache sees the file. A symlink into the store stays
  # at epoch 1970 and the dashboard never reloads. YAML mode is not editable
  # in the UI.
  systemd.tmpfiles.rules = [
    "d /var/lib/hass/dashboards 0750 hass hass -"
  ];

  system.activationScripts.houseDashboards = ''
    ${lib.concatMapStrings (d: ''
      install -D -m 0644 ${./dashboards + "/${d.file}"} \
        /var/lib/hass/dashboards/${d.file}
      touch /var/lib/hass/dashboards/${d.file}
    '') dashboards}
    if [ -f /var/lib/hass/.storage/lovelace_dashboards ]; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq --argjson drop '["dashboard-toestellen","lovelace-energy","dashboard-hvac","air-quality","dashboard-maintenance","room-control","lovelace-lights","lovelace","ev-laadkosten-nota"]' '
        .data.items |= map(select(.url_path as $u | $drop | index($u) | not))
      ' /var/lib/hass/.storage/lovelace_dashboards > "$tmp"
      chown --reference=/var/lib/hass/.storage/lovelace_dashboards "$tmp"
      chmod --reference=/var/lib/hass/.storage/lovelace_dashboards "$tmp"
      mv "$tmp" /var/lib/hass/.storage/lovelace_dashboards
      rm -f \
        /var/lib/hass/.storage/lovelace.dashboard_toestellen \
        /var/lib/hass/.storage/lovelace.lovelace_energy \
        /var/lib/hass/.storage/lovelace.dashboard_hvac \
        /var/lib/hass/.storage/lovelace.air_quality \
        /var/lib/hass/.storage/lovelace.dashboard_maintenance \
        /var/lib/hass/.storage/lovelace.room_control \
        /var/lib/hass/.storage/lovelace.lovelace_lights \
        /var/lib/hass/.storage/lovelace.lovelace \
        /var/lib/hass/.storage/lovelace.ev_laadkosten_nota
    fi
  '';

  services.home-assistant.config.lovelace.dashboards = lib.listToAttrs (map (d: {
    name = d.url;
    value = {
      mode = "yaml";
      title = d.title;
      icon = d.icon;
      show_in_sidebar = true;
      filename = "dashboards/${d.file}";
    };
  }) dashboards);
}
