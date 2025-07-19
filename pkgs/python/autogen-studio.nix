{ lib, buildPythonApplication, fetchPypi, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python313.pkgs.buildPythonApplication rec {
  pname = "autogen-studio";
  version = "0.4.1";
  format = "setuptools";

  src = fetchPypi {
    inherit version;
    pname = "autogenstudio";
    hash  = "sha256-+0a5ZBYqz0rioEm6MN7IOcULy45TWi2D+RHgVHy/S+8=";
  };

  python = nixpkgs-unstable.python313;

  propagatedBuildInputs = with nixpkgs-unstable.python313Packages; [
    pydantic
    pydantic-settings
    fastapi    
    typer
    uvicorn
    aiofiles
    python-dotenv
    websockets
    numpy
    sqlmodel
    psycopg
    alembic
    loguru
    pyyaml
    (callPackage ./autogen-core.nix {nixpkgs-unstable = nixpkgs-unstable;})
    (callPackage ./autogen-agentchat.nix {nixpkgs-unstable = nixpkgs-unstable;})
    (callPackage ./autogen-ext.nix {nixpkgs-unstable = nixpkgs-unstable;})
    azure-identity

    # non declared dependencies
    html2text
  ];

  nativeBuildInputs = with nixpkgs-unstable.python313Packages; [
    hatchling
  ];

  postInstall = ''
    # Custom steps for frontend
    mkdir -p $out/autogenstudio/web
    cp -r autogenstudio/web/ui $out/autogenstudio/web/ui
  '';

  doCheck = true;

  pythonImportsCheck = [ "autogenstudio" ];

  # Metadata for the package
  meta = with lib; {
    description = "A low-code UI for prototyping multi-agent AI systems";
    homepage = "https://github.com/microsoft/autogen";
    license = licenses.mit;
    maintainers = with maintainers; [ "nathan-gs" ];  # Replace with your NixOS username or remove if not applicable
  };
}