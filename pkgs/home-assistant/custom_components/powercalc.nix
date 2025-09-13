{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.17.20";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-iXsztBLKZ9uMp40+i/2ACEuaZfenOTBNghm2pHXag08=";
  };
  
  propagatedBuildInputs = [
    pkgs.python313Packages.numpy
  ];

}
