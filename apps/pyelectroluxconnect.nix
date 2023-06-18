{ lib
, buildPythonApplication
, fetchPypi
, requests
, beautifulsoup4,
fetchFromGitHub
}:

buildPythonApplication rec {
  pname = "pyelectroluxconnect";
  version = "0.13.9";

  src = fetchFromGitHub {
    owner = "tomeko12";
    repo = "pyelectroluxconnect ";
    rev = "0.13.9";
    sha256 = "1jkbmaiwad5kmryqmm83jvab8vy6kxvj2v8vn0jggsa4xm7rzgwm";
  };

  propagatedBuildInputs = [ requests beautifulsoup4 ];

  meta = with lib; {
    description = "Python client package to communicate with the Electrolux Connectivity Platform";
    homepage = "https://github.com/tomeko12/pyelectroluxconnect";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
