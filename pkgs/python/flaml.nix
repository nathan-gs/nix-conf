{ lib, buildPythonPackage, fetchFromGitHub, python312Packages }:

buildPythonPackage rec {
  pname = "FLAML";
  version = "2.1.2";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-uhmfmRC/g6w0NX5KqLS4BM/fnQl/6u2xibA4rho4tFs=";
  };

  propagatedBuildInputs = [ 
    python312Packages.numpy
  ];

  doCheck = false;

  pythonImportsCheck = [ "flaml" ];
}
