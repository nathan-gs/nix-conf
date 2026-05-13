{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.20.14";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-Tm9h6ZHByuiM9XZz3D1TZR3ISbb16l0K1Vy8sJxI4+s=";
  };
  
  propagatedBuildInputs = [
    pkgs.python314Packages.numpy
  ];

}
