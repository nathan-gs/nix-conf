{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.24.1";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-sxwaly6JH3oJumcBzvbNPWJZVEuoOejvkaxiGa5fcnk=";
  };
  
  propagatedBuildInputs = [
    pkgs.python314Packages.numpy
  ];

}
