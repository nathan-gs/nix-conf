{ stdenv, pkgs, lib, buildPythonPackage, fetchFromGitHub }:

buildPythonPackage rec {
  pname = "pyelectroluxocp";
  version = "0.0.7";

  src = fetchFromGitHub {
    owner = "Woyken";
    repo = "py-electrolux-ocp";
    rev = version;
    sha256 = "sha256-MAW3ShBJF3xzHk3L/+2nVn1sJ/7RzEQElOjfd3/tOxs=";
  };

  propagatedBuildInputs = [
    pkgs.python311Packages.aiohttp
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
