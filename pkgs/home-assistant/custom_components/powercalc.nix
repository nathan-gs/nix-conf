{ stdenv, pkgs, fetchzip, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.9.8";
  src = fetchzip {
    url = "https://github.com/bramstroker/homeassistant-powercalc/releases/download/v${version}/powercalc.zip";
    hash = "sha256-OKEcGOptIp1CZd4lYYxnnJEkUAtvmei5OnKeywYiiLI=";
    stripRoot = false;
  };
  
  #installPhase = ''cp -a $src $out'';
  dontBuild = true;
}
