{ stdenv, pkgs, fetchzip }:

stdenv.mkDerivation rec {

  name = "powercalc";
  version = "v1.9.5";
  src = fetchzip {
    url = "https://github.com/bramstroker/homeassistant-powercalc/releases/download/${version}/powercalc.zip";
    hash = "sha256-+CbiE26ZiaPk4C9TJlT/jKKRq3NzDIR/LPrZ8dFVSSA=";
    stripRoot = false;
  };
  
  installPhase = ''cp -a $src $out'';
}
