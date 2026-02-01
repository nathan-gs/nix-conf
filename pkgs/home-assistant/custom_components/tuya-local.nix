{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,

  # dependencies
  tinytuya,
  tuya-device-sharing-sdk,
}:

buildHomeAssistantComponent rec {
  owner = "nathan-gs";
  domain = "tuya_local";
  version = "2026.1.1-nb";

  src = fetchFromGitHub {
    inherit owner;
    repo = "tuya-local";
    rev = "main";
    hash = "sha256-fmTmN7Z21zWpS773yPcEucxE1+dQzsU2z4t6+d70OFY=";
  };

  dependencies = [
    tinytuya
    tuya-device-sharing-sdk
  ];

  meta = {
    description = "Local support for Tuya devices in Home Assistant";
    homepage = "https://github.com/make-all/tuya-local";
    changelog = "https://github.com/make-all/tuya-local/releases/tag/${version}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ pathob ];
  };
}