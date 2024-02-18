{ stdenv, pkgs, lib, buildPythonPackage, fetchFromGitHub }:

buildPythonPackage rec {
  pname = "pyelectroluxocp";
  version = "0.0.12";

  src = fetchFromGitHub {
    owner = "Woyken";
    repo = "py-electrolux-ocp";
    rev = version;
    sha256 = "sha256-9LibWs5DKu39eJ10wX24AfLjKSZ4rJb06rlmrkszL6Q=";
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
