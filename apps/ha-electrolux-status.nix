{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-electrolux-status";
  src = fetchFromGitHub {
    owner = "mauro-midolo";
    repo = "homeassistant_electrolux_status";
    rev = "v2.6.1";
    sha256 = "lh4xh0MdmgKE2jykfzyvqr1s4QzJWFzdu10OHbOTMBI=";
  };

  
  installPhase = ''cp -a custom_components/electrolux_status $out'';
}
