{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent}:

buildHomeAssistantComponent rec {

  owner = "bajansen";
  domain = "frank_energie";
  version = "3.0.0";

  src = fetchFromGitHub {
    owner = owner;
    repo = "home-assistant-frank_energie";
    rev = "v${version}";
    sha256 = "sha256-GZXJEI5+wJR133w2KJrO4WJuFmO4XVrZrEHWFVqZThg=";
  };

  propagatedBuildInputs = [
    (pkgs.python312Packages.callPackage ../../python/frank-energie.nix {})
  ];

}
