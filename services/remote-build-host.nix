{ config, pkgs, lib, ... }:

{

  users.users.nixdist = {
    isSystemUser = true;
    createHome = false;
    uid = 500;
    openssh.authorizedKeys.keys = [
      config.secrets.ssh.nixdist.pub
    ];
    group = "nixdist";
    useDefaultShell = true;
  };

  users.groups.nixdist = {
    gid = 500;
  };
  
  nix.settings.trusted-users = [ "nixdist" ];
}