{ stdenv, pkgs, lib, buildPythonPackage, fetchFromGitHub, poetry-core }:

buildPythonPackage rec {
  pname = "frank-energie";
  version = "6.1.0";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "DCSBL";
    repo = "python-frank-energie";
    rev = version;
    sha256 = "sha256-bVtDAnIENuouh5tv5Vd33Xl+suJIse/iImg7uOzimW4=";
  };

  nativeBuildInputs = [ poetry-core ];

  propagatedBuildInputs = with pkgs.python312Packages; [
    setuptools
    python-dateutil
    aiohttp
    pyjwt
    syrupy
  ];

  doCheck = false;

  pythonImportsCheck = [ "python_frank_energie" ];

  meta = with lib; {
    description = "Asynchronous Python package for Frank Energie. Retrieve energy prices for Frank energie.";
    homepage = "https://github.com/DCSBL/python-frank-energie";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
