{ stdenv, pkgs, lib, fetchFromGitHub, makeWrapper, jq, curl, bash, gnugrep, mosquitto, openssl, getopt, gawk }:

stdenv.mkDerivation rec {
  name = "solis-control";

  src = fetchFromGitHub {
    owner = "nathan-gs";
    repo = "solis-control";
    rev = "v0.3.0";
    sha256 = "sha256-BgsXFCzWRtKk/2PNLtuyo2DeMaAhnY6sgFNMHW0ErYc=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -T -D -m755 solis-control.sh $out/bin/.solis-control.sh
    makeWrapper $out/bin/.solis-control.sh $out/bin/solis-control \
      --prefix PATH : ${lib.makeBinPath [ bash gnugrep jq mosquitto curl openssl getopt gawk ]}
  '';

}