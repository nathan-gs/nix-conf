{ lib, stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-hon";
  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    #rev = "0.3.0";
    rev = "4abe91331bea02ce13e2d477901d734c39799573";
    sha256 =  "G5Xprax4hwd07mks7OKJRdNu+s8C7dtu+Tn/965GWXY=";
  };

  
  installPhase = ''cp -a custom_components/hon $out'';

  meta = with lib; {
   description = "Home Assistant component supporting hOn cloud.";
   homepage = "https://github.com/gvigroux/hon";
   license = licenses.asl20;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
