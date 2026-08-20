{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "Pho3niX90";
  domain = "solis_modbus";
  version = "4.2.5";

  src = fetchFromGitHub {
    owner = owner;
    repo = "solis_modbus";
    rev = "v${version}";
    sha256 = "sha256-hzkw+KXp+Ck5bTpMX3YzZe7etMzoxoLHo13jX/1NWEI=";
  };

  propagatedBuildInputs = [
    pkgs.python314Packages.pymodbus
  ];

}
