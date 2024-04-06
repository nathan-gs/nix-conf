{ stdenv, pkgs, lib, buildPythonPackage, fetchFromGitHub }:

buildPythonPackage rec {
  pname = "pyelectroluxocp";
  version = "0.0.16";

  src = fetchFromGitHub {
    owner = "Woyken";
    repo = "py-electrolux-ocp";
    rev = version;
    sha256 = "sha256-vuW9I5PuIRh8jG4NaEeX0f6pWD3n89Oevv/fhVLn4I8=";
  };

  propagatedBuildInputs = [
    pkgs.python311Packages.aiohttp
    pkgs.python311Packages.aiohttp-retry
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
