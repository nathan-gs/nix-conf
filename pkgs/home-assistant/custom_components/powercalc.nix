{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.9.11";

  src = fetchFromGitHub {
    #url = "https://github.com/bramstroker/homeassistant-powercalc/releases/download/v${version}/powercalc.zip";
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-bDA4G+UmZVZ2CCqRkBVO72IM1OalZ5D41ltdUnTYw60=";
  };
  
  propagatedBuildInputs = [
    pkgs.python311Packages.numpy
  ];

}
