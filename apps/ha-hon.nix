{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-hon";
  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = "0.3.0";
    sha256 =  "Vj6nPx1D7nFFG5OxMfFBX8vGmRG/uom7pvwnTjC+YM4=";
  };

  
  installPhase = ''cp -a custom_components/hon $out'';
}
