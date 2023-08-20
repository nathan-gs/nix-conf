{ config, pkgs, ... }:

{

    services.samba = {
#        package = pkgs.samba4Full;
        enable = true;

#    securityType = "share";
        nsswins = true;
 #       syncPasswordsByPam = true;
  shares = {
    media = {
      path = "/media/media";
      "read only" = false;
      "directory mask" = "0777";
      "create mask" = "0777";
    };
    backup-jo = {
      path = "/media/documents/jo";
      "read only" = false;
      "directory mask" = "0777";
      "create mask" = "0777";
    };
    
    nathan = {
      path = "/media/documents/nathan";
      "valid users" = "nathan";
    };

    fn-fotos = {
      path = "/media/documents/nathan/onedrive_nathan_personal/fn-fotos";
      "valid users" = "@users";
      "force user" = "nathan";
    };
  };

        extraConfig = ''
#[nathan]
#   path = /media/documents/nathan
#   directory mask = 0700
#   guest ok = no
#   create mask = 0700
#   browsable = no
#   guest only = no
#   comment = Nathan
#   force directory mask = 0700
#   force create mask = 0700
#   valid = nathan
#   writable = yes

[global]
   printcap name = /dev/null
   load printers = no

       '';
    };

  networking.firewall = {
    allowedTCPPorts = [ 137 138 139 445 ];
    allowedUDPPorts = [ 137 138 139 445 ];
  };
}
