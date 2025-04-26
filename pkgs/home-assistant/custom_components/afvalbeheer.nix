{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "5.6.0";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-s26FfFC4SIv+0kY/eTeLWynNyflEE9nDzPk3bsyj0TQ=";
  };

  propagatedBuildInputs = [
    pkgs.python313Packages.rsa
    pkgs.python313Packages.pycryptodome
  ];
  
}
