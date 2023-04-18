{ lib
, buildPythonApplication
, fetchPypi
, requests
, beautifulsoup4
}:

buildPythonApplication rec {
  pname = "pyelectroluxconnect";
  version = "0.13.4";

  src = builtins.fetchurl {
    url = "https://files.pythonhosted.org/packages/95/e5/2178c30625ce2f3ca51aad7c18e49a4ce89ce8437b7a03ba650d6ca58e5a/pyelectroluxconnect-0.3.14.tar.gz";
    sha256 = "857cd14fec134f0e4457f703d883f559d482a002c904d47bf80bbac32e9d77d3";
  };

  propagatedBuildInputs = [ requests beautifulsoup4 ];

  meta = with lib; {
    description = "Python client package to communicate with the Electrolux Connectivity Platform";
    homepage = "https://github.com/tomeko12/pyelectroluxconnect";
    license = licenses.asl20;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
