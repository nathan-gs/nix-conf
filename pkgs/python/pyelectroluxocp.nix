{ stdenv, pkgs, lib, buildPythonPackage, fetchFromGitHub }:

buildPythonPackage rec {
  pname = "pyelectroluxocp";
  version = "0.0.19";

  src = fetchFromGitHub {
    owner = "Woyken";
    repo = "py-electrolux-ocp";
    rev = "3851a94e07b78cdb8463463f3b89ce3917e427ff";
    sha256 = "sha256-P41o82aHY/MoQvY2VUtkt6HoTI4e8HYkgf+EC+ZaJsg=";
  };

  propagatedBuildInputs = [
    pkgs.python313Packages.aiohttp
    pkgs.python313Packages.aiohttp-retry
  ];

  doCheck = false;

  pythonImportsCheck = [ "pyelectroluxocp" ];

  meta = with lib; {
    description = "Python package wrapper around Electrolux OneApp (OCP) api";
    homepage = "https://github.com/Woyken/py-electrolux-ocp";
    license = licenses.mit;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
