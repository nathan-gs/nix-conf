{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "2.3.4";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-NSgX20AKEsxXRRlcM1nr7FyZ3+JjqiO/UubV6J+pFdA=";
  };

  # TODO: remove when new version of pyelectroluxocp is released
  dontCheckManifest = true;

  propagatedBuildInputs = [
    (pkgs.python314Packages.callPackage ../../python/pyelectroluxocp.nix {})
    pkgs.python314Packages.aiofiles
  ];

}
