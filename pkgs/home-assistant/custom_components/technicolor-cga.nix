{ pkgs, fetchFromGitHub, buildHomeAssistantComponent, python3Packages }:

buildHomeAssistantComponent rec {

  owner = "woody6402";
  domain = "technicolor_cga";
  version = "0.9.5";

  src = fetchFromGitHub {
    owner = "woody6402";
    repo = "techniclor_cga";              # note: upstream repo name is misspelled
    rev = version;
    hash = "sha256-6Zxf5vAkQpkBKfQxUV3boGiEN139xERoQoBxtIwFDGY=";
  };

  # manifest declares no requirements, but the code imports `requests`
  # (which is also a Home Assistant core dependency).
  dependencies = [ python3Packages.requests ];

}
