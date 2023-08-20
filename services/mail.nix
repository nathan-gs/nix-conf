{ config, pkgs, lib, ... }:
{
  # Email
  programs.msmtp = {
    enable = true;
    extraConfig = ''
      defaults
      
      account sendgrid
      aliases /etc/aliases
      auth on
      auto_from on
      user ${config.secrets.sendgrid.api.user}
      host ${config.secrets.sendgrid.host}
      maildomain nathan.gs
      password ${config.secrets.sendgrid.api.key}
      port ${toString config.secrets.sendgrid.port}
      syslog on
      tls on

      account default : sendgrid
    '';
    setSendmail = true;
  };

  environment.etc.aliases.text = ''
    default: ${config.secrets.email}
  '';
}
