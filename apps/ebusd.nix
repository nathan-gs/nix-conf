{ lib, stdenv, pkgs, fetchFromGitHub, argparse, mosquitto, cmake, autoconf, automake, libtool, pkg-config, ssl }:

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
    automake
    libtool
    pkg-config
  ];

  buildInputs = [
    argparse
    mosquitto
    ssl
  ];

  patches = [
    ./ebusd-cmake.patch
  ];

  cmakeFlags = [
    "-DCMAKE_INSTALL_SYSCONFDIR=${placeholder "out"}/etc"
    "-DCMAKE_INSTALL_BINDIR=${placeholder "out"}/bin"
    "-DCMAKE_INSTALL_LOCALSTATEDIR=${placeholder "TMPDIR"}"
  ];

  postInstall = ''
    mv $out/usr/bin $out
    rmdir $out/usr
  '';


  meta = with lib; {
   description = "ebusd";
   homepage = "https://github.com/john30/ebusd";
   license = licenses.gpl3Only;
   maintainers = with maintainers; [ nathan-gs ];
 };
  
}
