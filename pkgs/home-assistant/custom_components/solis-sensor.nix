{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "hultenvp";  
  domain = "solis";
  version = "3.5.0";

  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v${version}";
    sha256 = "sha256-YtTwmjT3SHhXtsvglZfeL1kPwBdoEySfQHs4+S7ExJY=";
  };
}
