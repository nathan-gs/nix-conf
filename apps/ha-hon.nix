{ lib, stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-hon";
  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = "0.4.2";
    sha256 =  "5TPKuMVGcCTUkbC8DvORWvHJl4zdrn8gpYT5/rdT9EM=";
  };

  
  installPhase = ''cp -a custom_components/hon $out'';

  meta = with lib; {
   description = "Home Assistant component supporting hOn cloud.";
   homepage = "https://github.com/gvigroux/hon";
   license = licenses.asl20;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
