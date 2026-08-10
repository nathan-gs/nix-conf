{ lib, stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "gvigroux";
  domain = "hon";
  version = "0.8.4";

  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = version;
    sha256 = "sha256-QujeqAT9tfMyfT++kIqh+/x1TKSQ+BqzHbw1ToQUWms=";
  };


  meta = with lib; {
    description = "Home Assistant component supporting hOn cloud.";
    homepage = "https://github.com/gvigroux/hon";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
  
}
