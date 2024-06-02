{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent, python312Packages }:

buildHomeAssistantComponent  rec {

  owner = "veista";
  domain = "smartthings";
  version = "1.1.16";

  src = fetchFromGitHub {
    owner = owner;
    repo = domain;
    rev = "${version}";
    sha256 = "sha256-X3SYkg0B5pzEich7/4iUmlADJneVuT8HTVnIiC7odRE=";
  };

  # Workaround for minor dependency version mismatch
  dontCheckManifest = true;

  propagatedBuildInputs = [
    python312Packages.pysmartthings
    python312Packages.pysmartapp
  ];
  
}
