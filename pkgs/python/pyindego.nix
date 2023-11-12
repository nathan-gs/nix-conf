{ lib
, buildPythonPackage
, requests
, aiohttp
, pytz
, fetchgit
}:

buildPythonPackage rec {
  pname = "pyIndego";
  version = "3.1.1";

  src = fetchgit {
    url = "https://github.com/jm-73/pyIndego";
    rev = "cf45b9cfd7c2e56edfe5d3a8e2f2a6b0ad007c23";
    sha256 = "sha256-AF20MdEV9gCfbJe+huWczA0yK24zFaVHpuyqb09Ccrk=";
  };

  propagatedBuildInputs = [ requests aiohttp pytz ];

  doCheck = false;

  pythonImportsCheck = [ "pyIndego" ];

  meta = with lib; {
    description = "Python client package to communicate with the Bosch Indego platform";
    homepage = "https://github.com/jm-73/pyIndego/tree/master";
    license = licenses.mit;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
