{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "5.3.1";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-o6LUBffUQkAStVfPgW0votpS3lflNbXRaI1P8aWGpMg=";
  };

  propagatedBuildInputs = [
    pkgs.python311Packages.rsa
    pkgs.python311Packages.pycryptodome
  ];
  
}
