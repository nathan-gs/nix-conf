{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.17.0";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-P1ZTF9+EczBP3bSfkcp06em4TPtfKI93+fcMvQ5yvAw=";
  };
  
  propagatedBuildInputs = [
    pkgs.python313Packages.numpy
  ];

}
