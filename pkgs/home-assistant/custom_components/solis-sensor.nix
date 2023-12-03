{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-solis-sensor";
  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v3.5.0";
    sha256 = "sha256-YtTwmjT3SHhXtsvglZfeL1kPwBdoEySfQHs4+S7ExJY=";
  };

  
  installPhase = ''cp -a custom_components/solis $out'';
}
