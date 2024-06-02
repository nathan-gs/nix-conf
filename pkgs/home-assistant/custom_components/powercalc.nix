{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.12.6";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-oON9iTrjEPW9oK1BhaMvRIuRbVg5HDQvYMvY4ewNHNM=";
  };
  
  propagatedBuildInputs = [
    pkgs.python312Packages.numpy
  ];

}
