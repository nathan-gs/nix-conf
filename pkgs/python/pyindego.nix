{ lib, buildPythonPackage, fetchgit, python312Packages }:

buildPythonPackage rec {
  pname = "pyIndego";
  version = "3.1.1";

  src = fetchgit {
    url = "https://github.com/jm-73/pyIndego";
    rev = "f1aaae1d19898c9fa90989412880681ed46e50d2";
    sha256 = "sha256-jwRwteBfvQVvmFdPt9dyosWV4hFhjyWEb/7nOEzWJHk=";
  };

  propagatedBuildInputs = [
    python312Packages.requests
    python312Packages.aiohttp
    python312Packages.pytz
  ];

  doCheck = false;

  pythonImportsCheck = [ "pyIndego" ];

  meta = with lib; {
    description = "Python client package to communicate with the Bosch Indego platform";
    homepage = "https://github.com/jm-73/pyIndego/tree/master";
    license = licenses.mit;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
