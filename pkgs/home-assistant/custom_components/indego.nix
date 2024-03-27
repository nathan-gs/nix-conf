{ stdenv, pkgs, fetchgit, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {

  owner = "jm-73";
  domain = "indego";
  version = "5.6.1";

  src = fetchgit {
    url = "https://github.com/jm-73/Indego";
    rev = "0c543a3aae86eeb4019828c123b0f7ad1de954c6";
    sha256 = "sha256-1eZ3oQpzmFB64Qi0ohSBvYsHmcQfll0+rP9+BKMiBm8=";
  };

  propagatedBuildInputs = [
    (pkgs.python311Packages.callPackage ../../python/pyindego.nix {})
  ];

}
