{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "2.3.5";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-HCW/WzO4ZXk2pUe5CLhzO36vUIpzm/LsEM40kZt0oGw=";
  };

  # TODO: remove when new version of pyelectroluxocp is released
  dontCheckManifest = true;

  propagatedBuildInputs = [
    (pkgs.python314Packages.callPackage ../../python/pyelectroluxocp.nix {})
    pkgs.python314Packages.aiofiles
  ];

}
