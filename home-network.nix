{ lib, ... }:
{
  # Single source of truth for known LAN devices: MAC -> IP (for kea's DHCP
  # reservations, services/dhcp.nix), DNS name/aliases under l.nathan.gs
  # (services/blocky.nix), and whether the device gets internet access at
  # all (also services/blocky.nix). Add a device once here instead of
  # editing multiple files.
  options.homeNetwork.devices = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Hostname under l.nathan.gs and kea's DHCP hostname.";
          };
          mac = lib.mkOption { type = lib.types.str; };
          ip = lib.mkOption { type = lib.types.str; };
          aliases = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra hostnames under l.nathan.gs pointing at the same IP.";
          };
          internet = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether this device may resolve arbitrary internet domains.
              false restricts it to l.nathan.gs only (best-effort DNS-level
              cutoff — see services/blocky.nix).
            '';
          };
        };
      }
    );
    default = [ ];
  };

  config.homeNetwork.devices = [
    # Local important stuff: .2-.20
    # Reservation is inert (nhtpc's eno1 is statically configured, never a
    # DHCP client) — listed for the DNS aliases. Bare "nhtpc" (no suffix,
    # for clients that skip domain-search) is a separate customDNS mapping
    # in services/blocky.nix.
    {
      name = "nhtpc";
      mac = "70:85:c2:7a:99:94";
      ip = "192.168.0.2";
      aliases = [ "mqtt" "photoprism" "ha" "dns" "read" "m" ];
    }
    { name = "printer"; mac = "dc:a2:66:24:87:0c"; ip = "192.168.0.3"; }
    # Pinned to its original FritzBox-known IP (not the tidy range) —
    # testing the theory that FRITZ!OS keeps a persistent MAC<->IP binding
    # independent of its own DHCP server and refuses ARP to a MAC claiming
    # a different IP than what it remembers.
    { name = "ndesk"; mac = "d8:bb:c1:17:75:ec"; ip = "192.168.0.4"; }
    { name = "fritz-repeater"; mac = "4e:5d:35:81:90:ef"; ip = "192.168.0.5"; }

    # Smarthome sensors/gateways/appliances: .30-.69
    { name = "smartgatewayp1"; mac = "30:c6:f7:29:f4:54"; ip = "192.168.0.30"; internet = false; }
    { name = "smartgatewaywater"; mac = "ec:62:60:a7:20:94"; ip = "192.168.0.31"; internet = false; }
    { name = "wtw-itho"; mac = "b0:b2:1c:91:23:c4"; ip = "192.168.0.32"; }
    { name = "bluetooth-proxy-boven"; mac = "e4:b0:63:41:0c:28"; ip = "192.168.0.33"; internet = false; }
    { name = "ebus"; mac = "70:04:1d:00:4c:f8"; ip = "192.168.0.34"; internet = false; }
    { name = "car-charger"; mac = "f8:17:2d:cc:3a:95"; ip = "192.168.0.35"; internet = false; }
    { name = "robotic-mower"; mac = "94:e6:86:59:c9:78"; ip = "192.168.0.36"; }
    { name = "wasmachine"; mac = "44:3e:07:05:51:4d"; ip = "192.168.0.37"; }
    { name = "dishwasher"; mac = "34:ab:95:f0:65:58"; ip = "192.168.0.38"; }
    # SwitchBot hub + relay for the same physical robot vacuum.
    { name = "switchbot-robot-k10"; mac = "ec:31:4a:05:55:e9"; ip = "192.168.0.39"; }
    { name = "vacuum"; mac = "88:57:1d:cb:18:fb"; ip = "192.168.0.40"; }
    { name = "fotokader"; mac = "58:67:1a:ca:38:78"; ip = "192.168.0.41"; }

    # Media: .70-.79
    { name = "sonos-tv"; mac = "48:a6:b8:32:27:b5"; ip = "192.168.0.70"; }
    { name = "sonos-keuken"; mac = "34:7e:5c:f2:e5:b0"; ip = "192.168.0.71"; }
    { name = "sonos-3"; mac = "54:2a:1b:c3:02:66"; ip = "192.168.0.72"; }
    { name = "sonos-4"; mac = "48:a6:b8:ad:2a:b2"; ip = "192.168.0.73"; }
    { name = "appletv-woonkamer"; mac = "6c:4a:85:0c:1e:22"; ip = "192.168.0.74"; }
    { name = "fen-firetv"; mac = "88:29:bf:15:11:40"; ip = "192.168.0.75"; }
    { name = "fen-xgimi"; mac = "4c:24:ce:8c:13:f6"; ip = "192.168.0.76"; }
  ];
}
