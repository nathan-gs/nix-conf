{ config, pkgs, lib, ... }:
{
  # DHCP moved off the router (it can't push a DHCP domain-suffix option),
  # onto nhtpc, so LAN clients get "l.nathan.gs" + blocky as DNS automatically.
  # Static reservations keep known infra/smarthome devices on fixed
  # addresses; everything else floats in .200-.250. Two of the four Sonos
  # units (see smarthome/appliances/sonos.nix) weren't visible on the LAN
  # when this was written, so they aren't reserved yet — add them here once
  # their MACs are known.
  networking.firewall.allowedUDPPorts = [ 67 ];

  services.kea.dhcp4 = {
    enable = true;
    settings = {
      interfaces-config.interfaces = [ "eno1" ];
      lease-database = {
        type = "memfile";
        persist = true;
        name = "/var/lib/kea/dhcp4.leases";
      };
      valid-lifetime = 43200;
      renew-timer = 10800;
      rebind-timer = 21600;

      subnet4 = [
        {
          id = 1;
          subnet = "192.168.1.0/24";
          pools = [
            { pool = "192.168.1.200 - 192.168.1.250"; }
          ];
          option-data = [
            { name = "routers"; data = "192.168.1.1"; }
            { name = "domain-name-servers"; data = "192.168.1.2"; }
            { name = "domain-name"; data = "l.nathan.gs"; }
            { name = "domain-search"; data = "l.nathan.gs"; }
          ];
          reservations = [
            # Infra: .2-.9
            { hw-address = "dc:a2:66:24:87:0c"; ip-address = "192.168.1.3"; hostname = "printer"; }
            { hw-address = "4e:5d:35:81:90:ef"; ip-address = "192.168.1.4"; hostname = "fritz-repeater"; }

            # Smarthome sensors/gateways/appliances: .10-.19
            { hw-address = "30:c6:f7:29:f4:54"; ip-address = "192.168.1.10"; hostname = "smartgatewayp1"; }
            { hw-address = "ec:62:60:a7:20:94"; ip-address = "192.168.1.11"; hostname = "smartgatewaywater"; }
            { hw-address = "b0:b2:1c:91:23:c4"; ip-address = "192.168.1.12"; hostname = "wtw-itho"; }
            { hw-address = "e4:b0:63:41:0c:28"; ip-address = "192.168.1.13"; hostname = "bluetooth-proxy-boven"; }
            { hw-address = "70:04:1d:00:4c:f8"; ip-address = "192.168.1.14"; hostname = "ebus"; }
            { hw-address = "f8:17:2d:cc:3a:95"; ip-address = "192.168.1.15"; hostname = "car-charger"; }
            { hw-address = "94:e6:86:59:c9:78"; ip-address = "192.168.1.16"; hostname = "robotic-mower"; }
            { hw-address = "44:3e:07:05:51:4d"; ip-address = "192.168.1.17"; hostname = "wasmachine"; }

            # Sonos: .30-.39 (see smarthome/appliances/sonos.nix)
            { hw-address = "48:a6:b8:32:27:b5"; ip-address = "192.168.1.30"; hostname = "sonos-1"; }
            { hw-address = "34:7e:5c:f2:e5:b0"; ip-address = "192.168.1.31"; hostname = "sonos-2"; }
          ];
        }
      ];
    };
  };
}
