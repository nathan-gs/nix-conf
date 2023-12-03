{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-electrolux-status";
  src = fetchFromGitHub {
    owner = "mauro-midolo";
    repo = "homeassistant_electrolux_status";
    rev = "v4.1.0";
    sha256 = "sha256-85p4eG0ePW2EI6vzksSbWLhNfkdrzCiu1KChuPwSobU=";
  };

  
  installPhase = ''cp -a custom_components/electrolux_status $out'';
}
