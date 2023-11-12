{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-solis-sensor";
  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v3.4.3";
    sha256 = "cpBqL9kMMGaCSTXAHCjGd3N9yYvuzTO5GPyPr8ht4jQ=";
  };

  
  installPhase = ''cp -a custom_components/solis $out'';
}
