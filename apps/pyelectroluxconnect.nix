{ lib
, buildPythonPackage
, fetchPypi
, requests
, beautifulsoup4,
fetchFromGitHub
}:

buildPythonPackage rec {
  pname = "pyelectroluxconnect";
  version = "0.3.19";

  src = fetchFromGitHub {
    owner = "tomeko12";
    repo = "pyelectroluxconnect";
    rev = version;
    sha256 = "1jkbmaiwad5kmryqmm83jvab8vy6kxvj2v8vn0jggsa4xm7rzgwm";
  };

  propagatedBuildInputs = [ requests beautifulsoup4 ];

  doCheck = false;

  pythonImportsCheck = [ "pyelectroluxconnect" ];

  meta = with lib; {
    description = "Python client package to communicate with the Electrolux Connectivity Platform";
    homepage = "https://github.com/tomeko12/pyelectroluxconnect";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
