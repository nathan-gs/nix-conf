{ config, pkgs, lib, ... }:
{
  # mDNS aliases for the router-imposed lack of a DHCP domain suffix: LAN
  # clients can't be handed "l.nathan.gs" automatically, so publish short
  # <name>.local records instead via avahi. Let's Encrypt (and every public
  # CA) refuses to issue certs for .local, so these are HTTP-only and just
  # redirect to the real, already-certed https://<name>.nathan.gs — no
  # cert warnings, and ha.l.nathan.gs/photoprism.l.nathan.gs/etc still work
  # as-is for anyone who types the full name.
  services.avahi = {
    enable = true;
    publish.enable = true;
  };

  environment.etc."avahi/hosts".text = ''
    192.168.1.2 ha.local
    192.168.1.2 dns.local
    192.168.1.2 photoprism.local
  '';

  services.nginx.virtualHosts = {
    "ha.local".locations."/".return = "301 https://ha.nathan.gs$request_uri";
    "dns.local".locations."/".return = "301 https://dns.nathan.gs$request_uri";
    "photoprism.local".locations."/".return = "301 https://photoprism.nathan.gs$request_uri";
  };
}
