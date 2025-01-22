{ lib, buildPythonPackage, fetchPypi, fetchurl, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python312.pkgs.buildPythonApplication rec {
  pname = "autogen-core";
  version = "0.4.3";

  src = fetchPypi {
    inherit version;
    pname = "autogen_core";
    hash  = "sha256-ObiJ/bA/WNHWVqyKyouA0o1EeypQX3f9LOJ7kysCqoU=";
  };

  propagatedBuildInputs = with nixpkgs-unstable.python312Packages; [
    pillow
    typing-extensions
    pydantic
    protobuf
    opentelemetry-api
    jsonref
  ];

  nativeBuildInputs = with nixpkgs-unstable.python312Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_core" ];
}
