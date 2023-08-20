{ config, pkgs, lib, ... }:
{

  networking.firewall.allowedTCPPorts = [ 22 ];
  
  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  services.openssh.settings.PermitRootLogin = "no";
  services.openssh.ports = [22];

  services.openssh.extraConfig = ''
    Match Group mediaonly
      ChrootDirectory /media/media
      ForceCommand internal-sftp
      AllowTcpForwarding no
      X11Forwarding no
  '';

  services.fail2ban.jails = {
    sshd = ''
      enabled = true
      mode = extra
    '';
    sshd-aggresive = ''
      enabled = true
      filter = sshd[mode=aggressive]
    '';
  };



}
