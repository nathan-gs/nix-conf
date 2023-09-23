{ stdenv, pkgs, fetchgit }:

stdenv.mkDerivation rec {
  name = "ha-indego";
  src = fetchgit {
    url = "https://github.com/jm-73/Indego";
    rev = "0c543a3aae86eeb4019828c123b0f7ad1de954c6";
    sha256 = "sha256-1eZ3oQpzmFB64Qi0ohSBvYsHmcQfll0+rP9+BKMiBm8=";
  };

  
  installPhase = ''cp -a custom_components/indego $out'';
}