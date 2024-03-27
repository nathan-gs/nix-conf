{ lib, buildPythonApplication, fetchPypi, python311Packages }:

buildPythonApplication rec {
  pname = "autogenstudio";
  version = "0.0.56";

  src = fetchPypi {
    inherit pname version;
    hash  = "sha256-KoLZ+ZArU8E+ik5VKDf20aX5QvAXHiWAQCyHy3INsF4=";
  };

  propagatedBuildInputs = [
    python311Packages.pydantic
    python311Packages.fastapi
    python311Packages.typer
    python311Packages.uvicorn
    #python311Packages.arxiv
    (python311Packages.callPackage ./autogen.nix {})
    python311Packages.python-dotenv
    python311Packages.websockets
    python311Packages.numpy
  ];

  doCheck = false;

  pythonImportsCheck = [ "autogenstudio" ];

}
