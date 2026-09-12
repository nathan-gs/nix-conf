{ pkgs, fetchFromGitHub, buildHomeAssistantComponent, python3Packages }:

buildHomeAssistantComponent rec {

  owner = "woody6402";
  domain = "technicolor_cga";
  version = "0.9.6b1";

  # Back on upstream: our DOCSIS RF + WAN/LAN sensors and the session/login
  # fixes (woody6402/techniclor_cga#3) were merged and released in 0.9.6b1,
  # which also adds centralized polling, WiFi sensors and opt-in session
  # takeover (force_logout).
  src = fetchFromGitHub {
    owner = "woody6402";
    repo = "techniclor_cga";              # note: upstream repo name is misspelled
    rev = version;
    hash = "sha256-v8TfHb1yB+CerY0PaAikrCoZt4jgU50QftVidF/V2g0=";
  };

  # manifest declares no requirements, but the code imports `requests`
  # (which is also a Home Assistant core dependency).
  dependencies = [ python3Packages.requests ];

}
