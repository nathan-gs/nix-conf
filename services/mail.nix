{ config, pkgs, lib, ... }:
{
  # Email
  programs.msmtp = {
    enable = true;
    extraConfig = ''
      defaults
      
      account apimailer
      aliases /etc/aliases
      auth on
      auto_from on
      user ${config.secrets.smtp.user}
      host ${config.secrets.smtp.host}
      maildomain nathan.gs
      password ${config.secrets.smtp.password}
      port ${toString config.secrets.smtp.port}
      syslog on
      tls on

      account default : apimailer
    '';
    setSendmail = true;
  };

  environment.etc.aliases.text = ''
    default: ${config.secrets.email}
  '';
}
