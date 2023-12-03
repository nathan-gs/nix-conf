{ stdenv, pkgs, fetchzip }:

stdenv.mkDerivation rec {

  name = "powercalc";
  version = "v1.9.8";
  src = fetchzip {
    url = "https://github.com/bramstroker/homeassistant-powercalc/releases/download/${version}/powercalc.zip";
    hash = "sha256-OKEcGOptIp1CZd4lYYxnnJEkUAtvmei5OnKeywYiiLI=";
    stripRoot = false;
  };
  
  installPhase = ''cp -a $src $out'';
}
