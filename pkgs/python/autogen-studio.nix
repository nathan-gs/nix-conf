{ lib, buildPythonApplication, fetchPypi, nixpkgs-unstable, pkgs }:

nixpkgs-unstable.python312.pkgs.buildPythonApplication rec {
  pname = "autogen-studio";
  version = "0.4.0.3";

  src = fetchPypi {
    inherit version;
    pname = "autogenstudio";
    hash  = "sha256-Bf995PdtjoMEE11WqEZIiY+Ua/tan+8ZzA3qn/emHt4=";
  };

  python = nixpkgs-unstable.python312;

  propagatedBuildInputs = with nixpkgs-unstable.python312Packages; [
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
    (callPackage ./autogen-core.nix {nixpkgs-unstable = nixpkgs-unstable;})
    (callPackage ./autogen-agentchat.nix {nixpkgs-unstable = nixpkgs-unstable;})
    (callPackage ./autogen-ext.nix {nixpkgs-unstable = nixpkgs-unstable;})
    azure-identity
  ];

  nativeBuildInputs = with nixpkgs-unstable.python312Packages; [
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
    maintainers = with maintainers; [ "your-username" ];  # Replace with your NixOS username or remove if not applicable
  };
}