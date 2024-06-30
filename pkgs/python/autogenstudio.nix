{ lib, buildPythonApplication, fetchPypi, python312Packages }:

buildPythonApplication rec {
  pname = "autogenstudio";
  version = "0.1.2";

  src = fetchPypi {
    inherit pname version;
    hash  = "sha256-4WPtSC7+ySJUUNaneRAytjMRtlOAl9jjBbCs7gdUI+U=";
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
    python312Packages.sqlalchemy
    python312Packages.sqlmodel
    python312Packages.loguru
    python312Packages.alembic
  ];

  doCheck = false;

  pythonImportsCheck = [ "autogenstudio" ];

}
