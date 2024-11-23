{ stdenv, pkgs, lib, fetchFromGitHub, makeWrapper, jq, curl, bash, gnugrep, mosquitto, openssl, getopt, gawk }:

stdenv.mkDerivation rec {
  name = "solis-control";

  src = fetchFromGitHub {
    owner = "nathan-gs";
    repo = "solis-control";
    rev = "v0.2.1";
    sha256 = "sha256-JZLQCsjwGQCbw84R3XdHYKGe3+qFnE/FXvlmgkve6Qg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -T -D -m755 solis-control.sh $out/bin/.solis-control.sh
    makeWrapper $out/bin/.solis-control.sh $out/bin/solis-control \
      --prefix PATH : ${lib.makeBinPath [ bash gnugrep jq mosquitto curl openssl getopt gawk ]}
  '';

}