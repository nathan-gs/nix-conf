{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "1.0.19";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-QRLsWaQqg4aIL/oMmhioyF7jUQ5I7jTeQMKehu0qLsw=";
  };

  propagatedBuildInputs = [
    (pkgs.python312Packages.callPackage ../../python/pyelectroluxocp.nix {})
  ];

}
