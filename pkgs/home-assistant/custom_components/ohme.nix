{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent  rec {

  owner = "dan-r";
  domain = "ohme";
  version = "1.1.1";

  src = fetchFromGitHub {
    inherit owner;
    repo = "HomeAssistant-Ohme";
    rev = "v${version}";
    sha256 = "sha256-D6W/Q5fKVRuPZ51NAGDoEfUTw6V/2VuVGMOVRwGx2AQ=";
  };

  propagatedBuildInputs = [    
  ];
  
}
