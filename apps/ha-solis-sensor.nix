{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-solis-sensor";
  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v3.3.3";
    sha256 = "0l6ddvx15f3nz02qqzs79xh9y03dddjqpsi4ny03hbzdczf9grr9";
  };

  
  installPhase = ''cp -a custom_components/solis $out'';
}
