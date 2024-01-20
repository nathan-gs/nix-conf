{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent, pyelectroluxconnect }:

buildHomeAssistantComponent rec {

  owner = "mauro-modolo";
  domain = "electrolux_status";
  version = "5.0.0";

  src = fetchFromGitHub {
    owner = "mauro-midolo";
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-6PAvOebc8Dtj5uMadYfrzbuF0ToBnmW8VXpdk9c1N4o=";
  };

  propagatedBuildInputs = [
    pyelectroluxconnect
  ];

}
