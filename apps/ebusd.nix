{ lib, stdenv, pkgs, fetchFromGitHub, argparse, mosquitto, autoconf, pkg-config }:

stdenv.mkDerivation rec {
  name = "ebusd";
  src = fetchFromGitHub {
    owner = "john30";
    repo = "ebusd";
    rev = "23.2";
    sha256 = "2CkcTTxEzVrEPtUVVDxXPPkYqZT6+gsCcfTrt83sFv8=";
  };

  nativeBuildInputs = [
    autoconf
    pkg-config
  ];

  buildInputs = [
    argparse
    mosquitto
  ];


  installPhase = ''
    make prefix=$out sysconfdir=$out/etc install
  '';

  meta = with lib; {
   description = "ebusd";
   homepage = "https://github.com/john30/ebusd";
   license = licenses.gpl3Only;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
