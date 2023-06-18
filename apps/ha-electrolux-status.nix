{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-electrolux-status";
  src = fetchFromGitHub {
    owner = "mauro-midolo";
    repo = "homeassistant_electrolux_status";
    rev = "v2.12.0";
    sha256 = "0wfvpmj5d129a4iy2hvcfpq9877zajs93arm54n0l7ly2pcn644n";
  };

  
  installPhase = ''cp -a custom_components/electrolux_status $out'';
}
