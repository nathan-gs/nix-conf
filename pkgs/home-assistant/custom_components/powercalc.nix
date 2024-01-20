{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.10.0";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-C4gU9cmiUsFHdByGv3qR4pEAMO49CbpQYH4BsSOomnc=";
  };
  
  propagatedBuildInputs = [
    pkgs.python311Packages.numpy
  ];

}
