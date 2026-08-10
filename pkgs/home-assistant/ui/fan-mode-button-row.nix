{ stdenv, pkgs, fetchgit }:

stdenv.mkDerivation rec {
  name = "ha-fan-mode-button-row";
  src = fetchgit {
    url = "https://github.com/finity69x2/fan-mode-button-row";
    rev = "95473adfef9621c692ead8c06b3e67272a7ab2a3";
    sha256 = "sha256-DUSH76ReCYitXOBLwzCrLo2wXNX+TBBvYsbdONdehG8=";
  };

  
  installPhase = ''cp -a dist/* $out'';
}
