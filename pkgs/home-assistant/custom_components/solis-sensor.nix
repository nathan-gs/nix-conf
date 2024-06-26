{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "hultenvp";  
  domain = "solis";
  version = "3.5.2";

  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v${version}";
    sha256 = "sha256-Dibn8WTFFnyZnoXYUJ+ZmHBKhBRbWil3eMFUebWckQA=";
  };
}
