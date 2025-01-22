{ lib, buildPythonPackage, fetchPypi, fetchurl, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python312.pkgs.buildPythonPackage rec {
  pname = "autogen-agentchat";
  version = "0.4.3";

  src = fetchPypi {
    inherit version;
    pname = "autogen_agentchat";
    hash  = "sha256-KLd8ym8sbyExnA9+jAfQVZyJ2YmdADedGwtAWrfI5eo=";
  };

  propagatedBuildInputs = with nixpkgs-unstable.python312Packages; [
    (callPackage ./autogen-core.nix {nixpkgs-unstable = nixpkgs-unstable;})
  ];

  nativeBuildInputs = with nixpkgs-unstable.python312Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_agentchat" ];
}
