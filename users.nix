{ config, lib, pkgs, ... }:

{
  users.extraUsers.nathan = {
    isNormalUser = true;
    uid = 2000;
    extraGroups = [ "wheel" "docker" "media" "networkmanager" ];
    openssh.authorizedKeys.keys = [
      config.secrets.ssh.ngo.pub
      config.secrets.ssh.nathan-2021.pub
    ];
  };

  users.extraUsers.femke = {
    uid = 2001;
    extraGroups = [ "media" ];
    isNormalUser = true;
  };

  users.groups.media = {
    gid = 2001;
  };

  security.sudo.wheelNeedsPassword = false;

  # Warning true is only valid when setting a hashedPassword.
  users.mutableUsers = true;

}
