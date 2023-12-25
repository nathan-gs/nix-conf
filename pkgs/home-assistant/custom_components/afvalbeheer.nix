{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "5.2.8";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-l4v3QHiGXdWxt3bh6oIBlJYwDxpi3h2K1u0EmpA5oao=";
  };

  
  #installPhase = ''cp -a custom_components/afvalbeheer $out'';

  dontBuild = true;
}
