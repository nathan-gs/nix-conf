{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-ui-auto-entities";

  src = fetchFromGitHub {
    owner = "thomasloven";
    repo = "lovelace-auto-entities";
    rev = "v1.16.1";
    sha256 = "sha256-yMqf4LA/fBTIrrYwacUTb2fL758ZB1k471vdsHAiOj8=";
  };

  
  installPhase = ''cp auto-entities.js $out'';
}