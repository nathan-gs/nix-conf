{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-afvalbeheer";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v5.2.8";
    sha256 = "sha256-l4v3QHiGXdWxt3bh6oIBlJYwDxpi3h2K1u0EmpA5oao=";
  };

  
  installPhase = ''cp -a custom_components/afvalbeheer $out'';
}
