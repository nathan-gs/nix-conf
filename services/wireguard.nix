{ config, pkgs, lib, ... }:
{
  # Wireguard
   networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  }; 
  
  systemd.services.wireguard-reresolve-dns = lib.mkIf false {
    description = "reresolve-dns"; 
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.wireguard-tools pkgs.bash pkgs.gawk ];
    script = ''
      SERVICE_NAME="$(systemctl list-units --type service --plain wg-quick* | grep wg-quick | awk '{print $1}' | head -n 1)"
      CONFIG_FILE="$(cat $(systemctl cat $SERVICE_NAME | grep ExecStart | sed 's/ExecStart=//') | grep 'wg-quick up' | sed 's/wg-quick up //')"
      bash ${pkgs.fetchgit {
              url = git://github.com/WireGuard/wireguard-tools;
              rev = "d8230ea0dcb02d716125b2b3c076f2de40ebed99";
              sha256 = "0d1m32ahdr22mm04zvp96w2s42z8i2awh6c6bmldly91l3fgdjph";
            }}/contrib/reresolve-dns/reresolve-dns.sh $CONFIG_FILE
      
    '';
    startAt = "*-*-* *:12:00";
  };
}
