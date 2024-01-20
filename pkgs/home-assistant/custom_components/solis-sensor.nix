{ stdenv, pkgs, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "hultenvp";  
  domain = "solis";
  version = "3.5.1";

  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v${version}";
    sha256 = "sha256-mvnC08AlCbTI24GhlAJ4docF7rNGTzvr9s0118Qsvik=";
  };
}
