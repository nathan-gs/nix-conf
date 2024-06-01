{ stdenv, pkgs, lib, fetchFromGitHub, makeWrapper, jq, curl, bash, gnugrep, mosquitto, getopt }:

stdenv.mkDerivation rec {
  name = "sos2mqtt";

  src = fetchFromGitHub {
    owner = "nathan-gs";
    repo = "sos2mqtt";
    rev = "v0.1.1";
    sha256 = "sha256-LJJvqfegtsWOTX/dV36/qDLD76zguWXzH9xAIjS7KR0=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -T -D -m755 sos2mqtt.sh $out/bin/.sos2mqtt.sh
    makeWrapper $out/bin/.sos2mqtt.sh $out/bin/sos2mqtt \
      --prefix PATH : ${lib.makeBinPath [ curl bash gnugrep jq mosquitto getopt ]}
  '';

}