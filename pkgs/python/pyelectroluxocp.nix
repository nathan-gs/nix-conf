{ stdenv, pkgs, lib, buildPythonPackage, fetchFromGitHub }:

buildPythonPackage rec {
  pname = "pyelectroluxocp";
  version = "0.1.3";

  src = fetchFromGitHub {
    owner = "Woyken";
    repo = "py-electrolux-ocp";
    rev = "${version}";
    sha256 = "sha256-3j7wzs86QAYpDwZlHY5EJPHI2af6RHdeHpiDkS7ZLGw=";
  };

  propagatedBuildInputs = [
    pkgs.python313Packages.aiohttp
    pkgs.python313Packages.aiohttp-retry
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
