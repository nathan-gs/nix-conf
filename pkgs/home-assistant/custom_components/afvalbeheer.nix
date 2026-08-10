{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "6.5.19";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-JzC3xjdt/hE/G0a8EBehB0qMKV4j7rg8rzohe2swFv0=";
  };

  propagatedBuildInputs = [
    pkgs.python314Packages.rsa
    pkgs.python314Packages.pycryptodome
  ];
  
}
