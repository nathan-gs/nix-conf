{ lib
, buildPythonApplication
, fetchPypi
, requests
, beautifulsoup4
}:

buildPythonApplication rec {
  pname = "pyelectroluxconnect";
  version = "0.13.4";

  src = fetchPypi {
    inherit pname version;
    sha256 = "d5f9389539673875712beba4936c4ace95d24324953c6f0408a858c534c0bf21";
  };

  propagatedBuildInputs = [ requests beautifulsoup4 ];

  meta = with lib; {
    description = "Python client package to communicate with the Electrolux Connectivity Platform";
    homepage = "https://github.com/tomeko12/pyelectroluxconnect";
    license = licenses.apache;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
