{ lib, buildPythonPackage, fetchPypi, fetchurl, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python313.pkgs.buildPythonApplication rec {
  pname = "azure-ai-inference";
  version = "1.0.0b8";
  format = "setuptools";

  #src = fetchPypi {
  #  inherit version;
  #  inherit pname;
  #  hash  = "";
  #};

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/73/bf/0c352b13299613124c4cb249c225702c807e4b5ee22d190e84756685c79a/azure_ai_inference-1.0.0b8.tar.gz";
    hash = "sha256-t7yqrF9T8r4GgErGx1W+lYOsa6md9TOjlw2ggYOLTME=";
  };

  propagatedBuildInputs = with nixpkgs-unstable.python313Packages; [
    isodate
    azure-core
    typing-extensions
  ];

  doCheck = true;

  pythonImportsCheck = [ "azure.ai" ];
}
