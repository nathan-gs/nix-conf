{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "pippyn";
  domain = "afvalbeheer";
  version = "5.2.14";

  src = fetchFromGitHub {
    owner = "pippyn";
    repo = "Home-Assistant-Sensor-Afvalbeheer";
    rev = "v${version}";
    sha256 = "sha256-fLwJ65z3jTwFb6CqMsOR6ANbmnwr93RQ8u9t1u8dkfs=";
  };

  propagatedBuildInputs = [
    pkgs.python311Packages.rsa
    pkgs.python311Packages.pycryptodome
  ];
  
}
