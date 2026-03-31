{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "2.1.0";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-w1X6P/e6noHfpeXLJ7MK35BEi2WBKoQwXhgwZidNNaA=";
  };

  # TODO: remove when new version of pyelectroluxocp is released
  dontCheckManifest = true;

  propagatedBuildInputs = [
    (pkgs.python314Packages.callPackage ../../python/pyelectroluxocp.nix {})
    pkgs.python314Packages.aiofiles
  ];

}
