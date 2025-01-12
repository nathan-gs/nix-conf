{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "hultenvp";  
  domain = "solis";
  version = "3.8.1";

  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v${version}";
    sha256 = "sha256-sjLHridYiF2x5XzW869BNjH9y2WtfvXXsNICKUmpOYM=";
  };

  propagatedBuildInputs = [
    pkgs.python312Packages.aiofiles
  ];
}
