{ config, pkgs, lib, ... }:
{
  # DHCP moved off the router (it can't push a DHCP domain-suffix option),
  # onto nhtpc, so LAN clients get "l.nathan.gs" + blocky as DNS automatically.
  # Static reservations (from home-network.nix) keep known devices on fixed
  # addresses; everything else floats in .200-.250.
  #
  # Devices with internet = false get nhtpc (192.168.0.2) as their gateway
  # instead of the Technicolor. Kea merges option-data by option code, so
  # this replaces "routers" only — DNS, domain-name and domain-search still
  # come from the subnet, and every other client still gets 192.168.0.1.
  # nhtpc drops what those hosts try to forward (computers/nhtpc.nix,
  # networking.nat.extraCommands). That rule is on FORWARD, not INPUT:
  # DHCP to UDP 67, DNS and MQTT to this host are unaffected, and a renew
  # is on-link to 192.168.0.2, so the new gateway cannot black-hole DHCP.
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
          subnet = config.homeNetwork.lanSubnet;
          pools = [
            { pool = "192.168.0.200 - 192.168.0.250"; }
          ];
          option-data = [
            { name = "routers"; data = "192.168.0.1"; }
            { name = "domain-name-servers"; data = "192.168.0.2"; }
            { name = "domain-name"; data = "l.nathan.gs"; }
            { name = "domain-search"; data = "l.nathan.gs"; }
          ];
          reservations = map (d: {
            hw-address = d.mac;
            ip-address = d.ip;
            hostname = d.name;
          } // lib.optionalAttrs (!d.internet) {
            option-data = [
              # nhtpc's eno1, same address as domain-name-servers above.
              { name = "routers"; data = "192.168.0.2"; }
            ];
          }) config.homeNetwork.devices;
        }
      ];
    };
  };
}
