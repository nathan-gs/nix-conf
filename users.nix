{ config, lib, pkgs, ... }:

{
  users.extraUsers.nathan = {
     isNormalUser = true;
     uid = 2000;
     extraGroups = [ "wheel" "docker" ];
     openssh.authorizedKeys.keys = [
       config.secrets.ssh.nathan.pub
       config.secrets.ssh.nathan-2021.pub
       config.secrets.ssh.nathan-nchromebook.pub
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

  users.extraUsers.nills = {
     isNormalUser = true;
     uid = 2004;
     openssh.authorizedKeys.keys = [
       config.secrets.ssh.nills.pub.k0
       config.secrets.ssh.nills.pub.k1
       config.secrets.ssh.nills.pub.k2
       config.secrets.ssh.nills.pub.k3
       config.secrets.ssh.nills.pub.k4
     ];
  };

  
  users.extraUsers.nhtpc-backup = {
    uid = 501;
    isNormalUser = true;
    openssh.authorizedKeys.keys = [
      config.secrets.ssh.nhtpc-backup.pub
    ];
  };

  users.users.mediaonly = {
    uid = 2003;
    group = "mediaonly";
    home = "/media/media";
    createHome = false;
    extraGroups = [ "users" ];
    isSystemUser = true;
  };

  users.groups.mediaonly = {
    gid = 2000;
  };  
  
  security.sudo.wheelNeedsPassword = false;  

  # Warning true is only valid when setting a hashedPassword.
  users.mutableUsers = true;

}
