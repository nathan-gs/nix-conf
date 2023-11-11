{ stdenv, pkgs, fetchurl }:

stdenv.mkDerivation rec {

  name = "apexcharts-card";
  version = "v2.0.4";
  src = fetchurl {
    url = "https://github.com/RomRider/apexcharts-card/releases/download/${version}/apexcharts-card.js";
    hash = "sha256-lcgnlOyebkR74vwPgi6604a5Pwnw6VVqpYaIqfljST4=";
  };

  unpackPhase = ":";

  installPhase = ''cp -a $src $out'';

}
