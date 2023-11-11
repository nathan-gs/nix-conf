{ stdenv, pkgs, fetchgit }:

stdenv.mkDerivation rec {
  name = "ha-fan-mode-button-row";
  src = fetchgit {
    url = "https://github.com/finity69x2/fan-mode-button-row";
    rev = "14d4ce6bd94dafbe2de1625e7f2599c5ceb1bdd9";
    sha256 = "sha256-QZbjEFX+r5+BGSIljdezJZFA6z9wbBHFFMk1AyGHtyE=";
  };

  
  installPhase = ''cp -a dist/* $out'';
}
