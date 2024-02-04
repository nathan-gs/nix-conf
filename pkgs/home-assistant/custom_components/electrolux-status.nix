{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent, pyelectroluxocp }:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "1.0";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-NrcafOZAVTaFSJF/1TRKeHms1P1HtcHR/pUYq9/UwWo=";
  };

  propagatedBuildInputs = [
    pyelectroluxocp
  ];

}
