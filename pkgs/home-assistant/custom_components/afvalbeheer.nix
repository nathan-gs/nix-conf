{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "6.5.13";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-8SJD+jrkgQghtTmW6oWfCUEZmPmWcExWmA1Uf6qu2zo=";
  };

  propagatedBuildInputs = [
    pkgs.python314Packages.rsa
    pkgs.python314Packages.pycryptodome
  ];
  
}
