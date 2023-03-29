{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-solis-sensor";
  src = fetchFromGitHub {
    owner = "hultenvp";
    repo = "solis-sensor";
    rev = "v3.3.2";
    sha256 = "uPGqK6qyglz9aIU3iV/VQbwXXsaBw4HyW7LqtP/xnMg=";
  };

  
  installPhase = ''cp -a custom_components/solis $out'';
}
