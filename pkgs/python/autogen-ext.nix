{ lib, buildPythonPackage, fetchPypi, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python312.pkgs.buildPythonPackage rec {
  pname = "autogen-ext";
  version = "0.4.3";

  src = fetchPypi {
    inherit version;
    pname = "autogen_ext";
    hash  = "sha256-oywWRvzN1dPyqByWHL8Y8OeV3JucTJ7Pv2Wag9XEmJY=";
  };

  propagatedBuildInputs = with nixpkgs-unstable.python312Packages; [
    (callPackage ./autogen-core.nix {nixpkgs-unstable = nixpkgs-unstable;})
    # langchain
    langchain-core
    # azure
    azure-core
    azure-identity
    # docker
    docker
    # openai
    openai
    tiktoken
    aiofiles
    # file-surfer
    (callPackage ./autogen-agentchat.nix {nixpkgs-unstable = nixpkgs-unstable;})
    markitdown
    # web-surfer
    playwright
    pillow
    # magentic-one


  ];

  nativeBuildInputs = with nixpkgs-unstable.python312Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_ext" ];
}
