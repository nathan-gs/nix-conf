{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent, python311Packages, buildPythonPackage }:

buildHomeAssistantComponent rec {

  owner = "mauro-modolo";
  domain = "electrolux_status";
  version = "4.1.0";

  src = fetchFromGitHub {
    owner = "mauro-midolo";
    repo = "homeassistant_electrolux_status";
    rev = "v${version}";
    sha256 = "sha256-85p4eG0ePW2EI6vzksSbWLhNfkdrzCiu1KChuPwSobU=";
  };

  propagatedBuildInputs = [
    python311Packages.requests
    python311Packages.beautifulsoup4
    (python311Packages.callPackage ../../python/pyelectroluxconnect.nix {}) 
  ];

  
  #installPhase = ''cp -a custom_components/electrolux_status $out'';
  dontBuild = true;
}
