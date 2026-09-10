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
    rev = "0d5b64e383e340c1c575e7e9e0eb5380293b10e4";
    hash = "sha256-tyFIYp8FVcsJyFfOigFW6ZGhCI6x53+iIuEy1iubHoA=";
  };

  # manifest declares no requirements, but the code imports `requests`
  # (which is also a Home Assistant core dependency).
  dependencies = [ python3Packages.requests ];

}
