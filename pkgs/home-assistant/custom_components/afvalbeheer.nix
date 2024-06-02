{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "5.3.4";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-oJldq6aPlxud5b4QVoAsJNsv4ZO2wU1/X/Q7OjXLSng=";
  };

  propagatedBuildInputs = [
    pkgs.python312Packages.rsa
    pkgs.python312Packages.pycryptodome
  ];
  
}
