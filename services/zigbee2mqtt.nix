{ config, pkgs, lib, ... }:
let
  # The frontend has no authentication of its own, so it listens on loopback
  # only and the sole way in is nginx's LAN/WireGuard-only vhost below.
  # Randomly picked high port, deliberately off the crowded 8080.
  frontendPort = 45338;
in
{
  systemd.services.zigbee2mqtt = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };

  services.zigbee2mqtt = {
    enable = true;
    package = pkgs.zigbee2mqtt;
    settings = {
      homeassistant =  {
        # otherwise RTVs don't report temp + calibration
        legacy_entity_attributes = true;
        legacy_triggers = false;
      };
      permit_join = false;
      serial = {
        port = "/dev/serial/by-id/usb-ITead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_72b6fe6b0c86ec1183d1591719c2d21c-if00-port0";
        adapter = "zstack";
      };
      frontend = {
        enabled = true;
        host = "127.0.0.1";
        port = frontendPort;
      };
      device_options = {
        retain = true;
      };
      advanced = {
        channel = 25;
        network_key = config.secrets.zigbee2mqtt.networkKey;
        log_output = [ "console" ];
        log_level = "warning";
      };
      mqtt = {
        version = 5;
        server = "mqtt://localhost:1883";
        user = "zigbee2mqtt";
        password =  config.secrets.mqtt.users.zigbee2mqtt.password;
      };
    };
  };

  # DNS-01 because z2m.l.nathan.gs / z2m.wg.nathan.gs only resolve on the
  # LAN/WireGuard and can't satisfy an HTTP-01 challenge. There is
  # deliberately no public z2m.nathan.gs: the frontend has no auth.
  security.acme.certs."z2m.l.nathan.gs" = {
    group = "nginx";
    dnsProvider = "cloudflare";
    environmentFile = pkgs.writeText "acme-z2m-cloudflare-env" ''
      CLOUDFLARE_EMAIL=${config.secrets.cloudflare.authEmail}
      CLOUDFLARE_API_KEY=${config.secrets.cloudflare.authKey}
    '';
    extraDomainNames = [ "z2m.wg.nathan.gs" ];
  };

  services.nginx.virtualHosts."z2m.l.nathan.gs" = {
    forceSSL = true;
    useACMEHost = "z2m.l.nathan.gs";
    serverAliases = [ "z2m.wg.nathan.gs" ];
    # No public name and no auth on the frontend, so the source ACL is the
    # only gate: deny outright rather than using the $homenet_reject guard.
    extraConfig = config.homeNetwork.nginxLanOnly;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString frontendPort}";
      proxyWebsockets = true; # the frontend talks to z2m over a websocket
    };
  };
}
