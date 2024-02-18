{ config, lib, pkgs, ... }:

{


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

  users.extraUsers.wesley = {
    isNormalUser = true;
    uid = 2005;
    openssh.authorizedKeys.keys = [
      config.secrets.ssh.wesley.pub.k0
    ];
    extraGroups = [ "media" ];
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


}
