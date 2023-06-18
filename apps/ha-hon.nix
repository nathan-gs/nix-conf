{ lib, stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-hon";
  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = "0.5.1";
    sha256 = "06xcgg7c0r3fkhjnnxa18hhp7dsc67kdrq6l2h9qm26ijbgxgzk0";
  };

  
  installPhase = ''cp -a custom_components/hon $out'';

  meta = with lib; {
   description = "Home Assistant component supporting hOn cloud.";
   homepage = "https://github.com/gvigroux/hon";
   license = licenses.asl20;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
