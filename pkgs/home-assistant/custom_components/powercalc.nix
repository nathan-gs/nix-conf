{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "bramstroker";
  domain = "powercalc";
  version = "1.16.2";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant-powercalc";
    rev = "refs/tags/v${version}";
    hash = "sha256-LvzJdDhQ65igV7sv30XA37KOcxo18jdVsgyeAVpgOrg=";
  };
  
  propagatedBuildInputs = [
    pkgs.python312Packages.numpy
  ];

}
