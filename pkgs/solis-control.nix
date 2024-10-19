{ stdenv, pkgs, lib, fetchFromGitHub, makeWrapper, jq, curl, bash, gnugrep, mosquitto, openssl, getopt, gawk }:

stdenv.mkDerivation rec {
  name = "solis-control";

  src = fetchFromGitHub {
    owner = "nathan-gs";
    repo = "solis-control";
    rev = "v0.1.3";
    sha256 = "sha256-27mVcS6SL6GKy0ntGMfj5NDOyKe92mCq7Xl0zMvQpI8=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    install -T -D -m755 solis-control.sh $out/bin/.solis-control.sh
    makeWrapper $out/bin/.solis-control.sh $out/bin/solis-control \
      --prefix PATH : ${lib.makeBinPath [ bash gnugrep jq mosquitto curl openssl getopt gawk ]}
  '';

}