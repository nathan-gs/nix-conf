{ config, pkgs, lib, ... }:
{
  # DHCP moved off the router (it can't push a DHCP domain-suffix option),
  # onto nhtpc, so LAN clients get "l.nathan.gs" + blocky as DNS automatically.
  # Static reservations (from home-network.nix) keep known devices on fixed
  # addresses; everything else floats in .200-.250.
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
          subnet = "192.168.0.0/24";
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
          }) config.homeNetwork.devices;
        }
      ];
    };
  };
}
