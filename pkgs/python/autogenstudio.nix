{ lib, buildPythonApplication, fetchPypi, python312Packages }:

buildPythonApplication rec {
  pname = "autogenstudio";
  version = "0.0.56";

  src = fetchPypi {
    inherit pname version;
    hash  = "sha256-KoLZ+ZArU8E+ik5VKDf20aX5QvAXHiWAQCyHy3INsF4=";
  };

  propagatedBuildInputs = [
    python312Packages.pydantic
    python312Packages.fastapi
    python312Packages.typer
    python312Packages.uvicorn
    #python312Packages.arxiv
    (python312Packages.callPackage ./autogen.nix {})
    python312Packages.python-dotenv
    python312Packages.websockets
    python312Packages.numpy
  ];

  doCheck = false;

  pythonImportsCheck = [ "autogenstudio" ];

}
