{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-ui-auto-entities";

  src = fetchFromGitHub {
    owner = "thomasloven";
    repo = "lovelace-auto-entities";
    rev = "1.12.1";
    sha256 = "sha256-yeIgE1YREmCKdjHAWlUf7RfDZfC+ww3+jR/8AdKtZ7U=";
  };

  
  installPhase = ''cp auto-entities.js $out'';
}