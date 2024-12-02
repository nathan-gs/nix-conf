{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "hultenvp";  
  domain = "solis";
  version = "3.7.1";

  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v${version}";
    sha256 = "sha256-oJXbDuHT5temcei3ea1cUsqVB70am6WZjHbIehnZs6k=";
  };

  propagatedBuildInputs = [
    # 24.0.0 is too new
    (pkgs.python312Packages.callPackage ../../python/aiofiles-23.2.1.nix {})
  ];
}
