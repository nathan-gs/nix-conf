{ lib, buildPythonPackage, fetchPypi, python312Packages }:

buildPythonPackage rec {
  pname = "autogen";
  version = "0.2.20";

  src = fetchPypi {
    inherit version;
    pname = "pyautogen";
    hash  = "sha256-pk8QwF+GpqH87AdL8N5R8u7PeHKX82bo4v/zOrbX/Hc=";
  };

  propagatedBuildInputs = [
    python312Packages.diskcache
    python312Packages.termcolor
    (python312Packages.callPackage ./flaml.nix {})
    (python312Packages.callPackage ./openai.nix {})
    python312Packages.numpy
    python312Packages.python-dotenv
    python312Packages.tiktoken
    python312Packages.pydantic
    python312Packages.docker
  ];

  doCheck = false;

  pythonImportsCheck = [ "autogen" ];
}
