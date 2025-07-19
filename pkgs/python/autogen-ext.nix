{ lib, buildPythonPackage, fetchPypi, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python313.pkgs.buildPythonPackage rec {
  pname = "autogen-ext";
  version = "0.4.5";
  format = "setuptools";

  src = fetchPypi {
    inherit version;
    pname = "autogen_ext";
    hash  = "sha256-zO4JPc17zZedbcex8z1QhXR66ur+4Idm4un9FeUgyFI=";
  };

  propagatedBuildInputs = with nixpkgs-unstable.python313Packages; [
    (callPackage ./autogen-core.nix {nixpkgs-unstable = nixpkgs-unstable;})
    # langchain
    langchain-core
    # azure
    azure-core
    azure-identity
    (callPackage ./azure-ai-inference.nix {nixpkgs-unstable = nixpkgs-unstable;})
    # docker
    docker
    # openai
    openai
    tiktoken
    aiofiles
    # file-surfer
    (callPackage ./autogen-agentchat.nix {nixpkgs-unstable = nixpkgs-unstable;})
    markitdown
    # graphrag
    #graphrag issue with gensim
    # web-surfer
    playwright
    pillow
    # magentic-one

    # video-surfer
    #opencv-python
    #ffmpeg-python
    #openai-whisper

    # diskcache
    diskcache

    # jupyter-executor
    ipykernel
    nbclient

    # rich
    rich

  ];

  nativeBuildInputs = with nixpkgs-unstable.python313Packages; [
    hatchling
  ];

  buildPhase = ''
    hatchling build
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogen_ext" ];
}
