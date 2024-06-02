{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "albaintor";
  domain = "electrolux_status";
  version = "1.0.17";

  src = fetchFromGitHub {
    owner = owner;
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-4VC7u0K9wGq2T0F83X4cZBvWwsdSuKSaBY7s36u2sQA=";
  };

  propagatedBuildInputs = [
    (pkgs.python312Packages.callPackage ../../python/pyelectroluxocp.nix {})
  ];

}
