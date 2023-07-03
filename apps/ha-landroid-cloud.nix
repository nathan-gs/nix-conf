{ stdenv, pkgs, fetchFromGitHub }:

stdenv.mkDerivation rec {
  name = "ha-landroid-cloud";
  src = fetchFromGitHub {
    owner = "MTran";
    repo = "landroid_cloud";
    rev = "v3.0.5";
    sha256 = "wcp155ZUGVZK5KpWLfBsx4tQrrClOt7xWJs7JpMOWn4=";
  };
  
  installPhase = ''cp -a custom_components/landroid_cloud $out'';
}
