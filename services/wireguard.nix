{ config, pkgs, lib, ... }:
{
  # Wireguard
   networking.firewall = {
    allowedUDPPorts = [ 51820 ]; # Clients and peers can use the same port, see listenport
  }; 
  
}
