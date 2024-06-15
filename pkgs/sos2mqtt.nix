{ stdenv, pkgs, lib, fetchFromGitHub, makeWrapper, jq, curl, bash, gnugrep, mosquitto, getopt }:

stdenv.mkDerivation rec {
  name = "sos2mqtt";

  src = fetchFromGitHub {
    owner = "nathan-gs";
    repo = "sos2mqtt";
    rev = "v0.1.2";
    sha256 = "sha256-qyvY8NgHlVNK6MEvQ9oYxB7IdpYsoEXtzDdDk9Nw7DY=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -T -D -m755 sos2mqtt.sh $out/bin/.sos2mqtt.sh
    makeWrapper $out/bin/.sos2mqtt.sh $out/bin/sos2mqtt \
      --prefix PATH : ${lib.makeBinPath [ curl bash gnugrep jq mosquitto getopt ]}
  '';

}