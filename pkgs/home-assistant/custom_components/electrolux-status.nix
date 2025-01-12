{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "2.0.9";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-jIzaj0NW1kBzHQrhyRWBfqtIdSXIGOAHB3X5MBadOf0=";
  };

  # TODO: remove when new version of pyelectroluxocp is released
  dontCheckManifest = true;

  propagatedBuildInputs = [
    (pkgs.python312Packages.callPackage ../../python/pyelectroluxocp.nix {})
  ];

}
