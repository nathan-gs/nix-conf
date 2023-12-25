{ lib
, buildPythonPackage
, fetchFromGitHub
}:

buildPythonPackage rec {
  pname = "pyelectroluxconnect";
  version = "0.3.20";

  src = fetchFromGitHub {
    owner = "tomeko12";
    repo = "pyelectroluxconnect";
    rev = version;
    sha256 = "sha256-5eTHJsE5Jof5WSZFkf8/1UQafpgxpGTPuDWQMENgAG0=";
  };

  #propagatedBuildInputs = [ requests beautifulsoup4 ];

  doCheck = false;

  pythonImportsCheck = [ "pyelectroluxconnect" ];

  meta = with lib; {
    description = "Python client package to communicate with the Electrolux Connectivity Platform";
    homepage = "https://github.com/tomeko12/pyelectroluxconnect";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
