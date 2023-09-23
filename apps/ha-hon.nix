{ lib, stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-hon";
  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = "0.6.5";
    sha256 = "sQlFtz+tZoH9niR7NGlAm7oUl95wKmc8G1Jg8CGu1To=";
  };

  
  installPhase = ''cp -a custom_components/hon $out'';

  meta = with lib; {
   description = "Home Assistant component supporting hOn cloud.";
   homepage = "https://github.com/gvigroux/hon";
   license = licenses.asl20;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
