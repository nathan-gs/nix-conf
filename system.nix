{ config, pkgs, lib, fetchgit, ... }:

{

  imports = [
    ./software.nix    
    ./hosts.nix
    ./services/ssh.nix
    ./services/fail2ban.nix
    ./services/mail.nix
    ./services/wireguard.nix
  ];

  # Install the flakes edition
  #nix.package = pkgs.nixFlakes;
  # Enable the nix 2.0 CLI and flakes support feature-flags
  nix.extraOptions = ''
    experimental-features = nix-command flakes 
    extra-substituters = https://devenv.cachix.org
    extra-trusted-public-keys = devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=

    trusted-users = root nathan
  '';

  # Set your time zone.
  time.timeZone = "Europe/Brussels";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  services.timesyncd.enable = true;

  # Cron
  services.cron.enable = false;

  # Kernel network hardening (defensive defaults).
  boot.kernel.sysctl = {
    # Reverse-path filtering: drop packets whose source address would route
    # back out a different interface (spoofed source addresses).
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    # Ignore ICMP echo to broadcast addresses (smurf amplification).
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    # Ignore bogus ICMP error responses.
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    # Don't accept ICMP redirects (we're not a router; redirects can be used
    # to MITM by injecting routes).
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.conf.default.secure_redirects" = 0;
    # Don't send redirects (we're not a router).
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.default.send_redirects" = 0;
    # Drop source-routed packets.
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv6.conf.all.accept_source_route" = 0;
    "net.ipv6.conf.default.accept_source_route" = 0;
    # Log packets with impossible source addresses.
    "net.ipv4.conf.all.log_martians" = 1;
    # SYN flood mitigation.
    "net.ipv4.tcp_syncookies" = 1;
    # Restrict dmesg to root (leaks kernel pointers / boot info).
    "kernel.dmesg_restrict" = 1;
    # Restrict access to kernel pointers via /proc.
    "kernel.kptr_restrict" = 2;
    # ptrace scope: only allow ptracing of descendants by default.
    "kernel.yama.ptrace_scope" = 1;
  };


  # Select internationalisation properties.
  # i18n = {
  #   consoleFont = "Lat2-Terminus16";
  #   consoleKeyMap = "us";
  #   defaultLocale = "en_US.UTF-8";
  # };


}
