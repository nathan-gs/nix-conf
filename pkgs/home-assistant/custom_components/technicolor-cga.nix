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
    rev = "9fa0b9202ae23c89efbf6fb80477136efe5cdf7e";
    hash = "sha256-4Hge3MLZTL6JKuYuBl13t8Q5sopqdaX+Dph6afFcYq8=";
  };

  # manifest declares no requirements, but the code imports `requests`
  # (which is also a Home Assistant core dependency).
  dependencies = [ python3Packages.requests ];

}
