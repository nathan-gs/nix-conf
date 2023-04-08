{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-electrolux-status";
  src = fetchFromGitHub {
    owner = "mauro-midolo";
    repo = "homeassistant_electrolux_status";
    rev = "v2.5.1";
    sha256 = "9k9pSp9QLMtv/tTq58uNFPxirt+eWpsKwLThEnJJI/Y=";
  };

  
  installPhase = ''cp -a custom_components/electrolux_status $out'';
}
