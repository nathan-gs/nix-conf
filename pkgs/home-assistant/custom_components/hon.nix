{ lib, stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "gvigroux";
  domain = "hon";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = version;
    sha256 = "sha256-z2qalYfhPFHeik45Udu9G7j0GK4B2fgh1lSApTHvV7w=";
  };


  meta = with lib; {
    description = "Home Assistant component supporting hOn cloud.";
    homepage = "https://github.com/gvigroux/hon";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
  
}
