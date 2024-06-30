{ lib, buildPythonPackage, fetchPypi, python312Packages }:

buildPythonPackage rec {
  pname = "autogen";
  version = "0.2.31";

  src = fetchPypi {
    inherit version;
    pname = "pyautogen";
    hash  = "sha256-FXptLGjx/gyNHgfGiG+Xli3IXv/Y2kuq19eAStKEzHY=";
  };

  propagatedBuildInputs = [
    python312Packages.diskcache
    python312Packages.termcolor
    (python312Packages.callPackage ./flaml.nix {})
    python312Packages.openai
    python312Packages.numpy
    python312Packages.python-dotenv
    python312Packages.tiktoken
    python312Packages.pydantic
    python312Packages.docker
  ];

  doCheck = false;

  pythonImportsCheck = [ "autogen" ];
}
