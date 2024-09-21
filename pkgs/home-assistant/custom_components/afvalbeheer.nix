{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "5.4.3";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-8z8OClC6H4C5kqx0lHAEGzcFpyyyI4AZ3W2+g5+vU70=";
  };

  propagatedBuildInputs = [
    pkgs.python312Packages.rsa
    pkgs.python312Packages.pycryptodome
  ];
  
}
