{ lib, buildPythonPackage, fetchPypi, fetchurl, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python313.pkgs.buildPythonApplication rec {
  pname = "autogen-core";
  version = "0.4.5";

  src = fetchPypi {
    inherit version;
    pname = "autogen_core";
    hash  = "sha256-2+CbpYW+8YoJm/vMSUOFyzgwhWM+6p4/0l0NOTk6U74=";
  };

  propagatedBuildInputs = with nixpkgs-unstable.python313Packages; [
    pillow
    typing-extensions
    pydantic
    protobuf
    opentelemetry-api
    jsonref
  ];

  nativeBuildInputs = with nixpkgs-unstable.python313Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_core" ];
}
