{ lib, stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "gvigroux";
  domain = "hon";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = version;
    sha256 = "sha256-hjO4cUGtNJr0wKoXBQ5DHGCy7a0f+u85fwTpoa9EiZQ=";
  };


  meta = with lib; {
   description = "Home Assistant component supporting hOn cloud.";
   homepage = "https://github.com/gvigroux/hon";
   license = licenses.asl20;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
