{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "1.0.12";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-KUkMzJXY9BuJq1fYHh3UtTj1YsE9pxhECIVI/3q0q70=";
  };

  propagatedBuildInputs = [
    (pkgs.python311Packages.callPackage ../../python/pyelectroluxocp.nix {})
  ];

}
