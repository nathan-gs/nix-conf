{ stdenv, pkgs, lib, buildPythonPackage, setuptools, fetchFromGitHub }:

buildPythonPackage rec {
  pname = "pyelectroluxocp";
  version = "0.1.3";
  #format = "setuptools";

  pyproject = true;
  build-system = [ setuptools ];

  src = fetchFromGitHub {
    owner = "Woyken";
    repo = "py-electrolux-ocp";
    rev = "${version}";
    sha256 = "sha256-3j7wzs86QAYpDwZlHY5EJPHI2af6RHdeHpiDkS7ZLGw=";
  };

  propagatedBuildInputs = [
    pkgs.python314Packages.aiohttp
    pkgs.python314Packages.aiohttp-retry
    pkgs.python314Packages.poetry-core
  ];

  doCheck = true;

  pythonImportsCheck = [ "pyelectroluxocp" ];

  meta = with lib; {
    description = "Python package wrapper around Electrolux OneApp (OCP) api";
    homepage = "https://github.com/Woyken/py-electrolux-ocp";
    license = licenses.mit;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
