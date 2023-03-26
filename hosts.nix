{ config, pkgs, lib, ... }:

{

  networking.extraHosts = ''
    192.168.1.126 solis-s3wifi
  '';

}