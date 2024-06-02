{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.10.4";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-gWhCQ0xygXyy6mduH47OBLFjTlu1DFe5mw3lIHI2kds=";
  };
  
  propagatedBuildInputs = [
    pkgs.python312Packages.numpy
  ];

}
