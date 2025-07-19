{ lib, buildPythonPackage, fetchPypi, fetchurl, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python313.pkgs.buildPythonPackage rec {
  pname = "autogen-agentchat";
  version = "0.4.5";
  format = "setuptools";

  src = fetchPypi {
    inherit version;
    pname = "autogen_agentchat";
    hash  = "sha256-qNVJO07GxF9NQMM8bTu5imQJ96ZCjOT6lkXlG/4tdAg=";
  };

  propagatedBuildInputs = with nixpkgs-unstable.python313Packages; [
    (callPackage ./autogen-core.nix {nixpkgs-unstable = nixpkgs-unstable;})
  ];

  nativeBuildInputs = with nixpkgs-unstable.python313Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_agentchat" ];
}
