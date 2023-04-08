{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-hon";
  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = "58ad8367cbf149f88faabde723db2f30af9f93ba";
    sha256 =  "JK4p0HN9xe3/aowC31hksmnZKmf855/nf4BQlmE1J90=";
  };

  
  installPhase = ''cp -a . $out'';
}
