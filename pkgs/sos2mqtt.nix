{ stdenv, pkgs, lib, fetchFromGitHub, makeWrapper, jq, curl, bash, gnugrep, mosquitto, getopt }:

stdenv.mkDerivation rec {
  name = "sos2mqtt";

  src = fetchFromGitHub {
    owner = "nathan-gs";
    repo = "sos2mqtt";
    rev = "v0.1.3";
    sha256 = "sha256-HDkdugH4PcizhfC/yKRzWWbKKlyk9J1OUCVL2fgB8Zg=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -T -D -m755 sos2mqtt.sh $out/bin/.sos2mqtt.sh
    makeWrapper $out/bin/.sos2mqtt.sh $out/bin/sos2mqtt \
      --prefix PATH : ${lib.makeBinPath [ curl bash gnugrep jq mosquitto getopt ]}
  '';

}