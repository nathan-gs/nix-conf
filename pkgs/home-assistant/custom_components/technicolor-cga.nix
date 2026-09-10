{ pkgs, fetchFromGitHub, buildHomeAssistantComponent, python3Packages }:

buildHomeAssistantComponent rec {

  owner = "nathan-gs";
  domain = "technicolor_cga";
  version = "0.9.5-docsis";

  # Pinned to our fork's docsis-sensors branch, which adds DOCSIS RF sensors
  # (downstream/upstream power, SNR, corrected/uncorrectable codewords) plus
  # WAN/LAN interface sensors (packets, bytes, errors, link status) that
  # upstream 0.9.5 fetches but never exposes. Submitted upstream as
  # woody6402/techniclor_cga#3 — repoint back to woody6402 once merged.
  src = fetchFromGitHub {
    owner = "nathan-gs";
    repo = "techniclor_cga";              # note: upstream repo name is misspelled
    rev = "2984cb0908976218a27fcc35538d54b6e49db3b2";
    hash = "sha256-Lk5KxeRMuDioCDrk7W5j4aQFL8BdhREwnOosRvzoO+M=";
  };

  # manifest declares no requirements, but the code imports `requests`
  # (which is also a Home Assistant core dependency).
  dependencies = [ python3Packages.requests ];

}
