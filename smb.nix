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
}
