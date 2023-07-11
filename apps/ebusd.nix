{ lib, stdenv, pkgs, fetchFromGitHub, argparse, mosquitto, cmake, autoconf, pkg-config }:

stdenv.mkDerivation rec {
  name = "ebusd";
  src = fetchFromGitHub {
    owner = "john30";
    repo = "ebusd";
    rev = "23.2";
    sha256 = "2CkcTTxEzVrEPtUVVDxXPPkYqZT6+gsCcfTrt83sFv8=";
  };

  nativeBuildInputs = [
    cmake
    autoconf
    pkg-config
  ];

  buildInputs = [
    argparse
    mosquitto
  ];

  #configureFlags = [
  #  "--sysconfdir=$out"
  #  "--localstatedir=$out"
  #];

  #cmakeFlags = [
  #  "-DCMAKE_INSTALL_PREFIX=$out"
  #  "-DCMAKE_INSTALL_SYSCONFDIR=$out"
  #  "-DCMAKE_INSTALL_LOCALSTATEDIR=$out"
  #];

  configurePhase = ''
    ./autogen.sh --prefix=$out --sysconfdir=$out/etc --localstatedir=$out/var

  '';

  meta = with lib; {
   description = "ebusd";
   homepage = "https://github.com/john30/ebusd";
   license = licenses.gpl3Only;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
