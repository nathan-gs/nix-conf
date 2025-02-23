{ lib, stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "gvigroux";
  domain = "hon";
  version = "0.7.13";

  src = fetchFromGitHub {
    owner = "gvigroux";
    repo = "hon";
    rev = version;
    sha256 = "sha256-q3lNxcjMLfNumj8CusKvkVevuLR2zFBOnLw5FdHEE74=";
  };


  meta = with lib; {
    description = "Home Assistant component supporting hOn cloud.";
    homepage = "https://github.com/gvigroux/hon";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
  
}
