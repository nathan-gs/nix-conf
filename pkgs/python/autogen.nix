{ lib, buildPythonPackage, fetchPypi, python311Packages }:

buildPythonPackage rec {
  pname = "autogen";
  version = "0.2.20";

  src = fetchPypi {
    inherit version;
    pname = "pyautogen";
    hash  = "sha256-pk8QwF+GpqH87AdL8N5R8u7PeHKX82bo4v/zOrbX/Hc=";
  };

  propagatedBuildInputs = [
    python311Packages.diskcache
    python311Packages.termcolor
    (python311Packages.callPackage ./flaml.nix {})
    (python311Packages.callPackage ./openai.nix {})
    python311Packages.numpy
    python311Packages.python-dotenv
    python311Packages.tiktoken
    python311Packages.pydantic
    python311Packages.docker
  ];

  doCheck = false;

  pythonImportsCheck = [ "autogen" ];
}
