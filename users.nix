{ config, lib, pkgs, ... }:

{
  users.extraUsers.nathan = {
     isNormalUser = true;
     uid = 2000;
     extraGroups = [ "wheel" "docker" ];
     openssh.authorizedKeys.keys = [
       "${builtins.readFile ./secrets/ssh.nathan.pub}"
       "${builtins.readFile ./secrets/ssh.nathan.nchromebook.pub}"
     ];
  };

  users.extraUsers.femke = {
    uid = 2001;
    isNormalUser = true;
  };

  users.extraUsers.jo = {
    uid = 2002;
    isNormalUser = true;
  };
  
  users.extraUsers.nhtpc-backup = {
    uid = 501;
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      "${builtins.readFile ./secrets/ssh.nhtpc-backup.pub}"
    ];
  };

  users.users.mediaonly = {
    uid = 2003;
    group = "mediaonly";
    home = "/media/media";
    createHome = false;
    extraGroups = [ "users" ];
  };

  users.groups.mediaonly = {
    gid = 2000;
  };  
  
  security.sudo.wheelNeedsPassword = false;  

  # Warning true is only valid when setting a hashedPassword.
  users.mutableUsers = true;

}
