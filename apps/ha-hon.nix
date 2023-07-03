{ lib, stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-hon";
  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = "0.5.2-Beta2";
    sha256 = "G6Z8ZrQs3XRP3VSCn4KDwzY9nPICPafBH2jFpgTiaZg=";
  };

  
  installPhase = ''cp -a custom_components/hon $out'';

  meta = with lib; {
   description = "Home Assistant component supporting hOn cloud.";
   homepage = "https://github.com/gvigroux/hon";
   license = licenses.asl20;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
