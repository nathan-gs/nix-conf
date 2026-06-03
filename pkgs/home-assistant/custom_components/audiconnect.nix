{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  beautifulsoup4,
}:

buildHomeAssistantComponent rec {
  owner = "audiconnect";
  domain = "audiconnect";
  version = "2.1.2";

  src = fetchFromGitHub {
    inherit owner;
    repo = "audi_connect_ha";
    rev = "v${version}";
    hash = "sha256-DzW0JJRObvKhhm67gLYp+EDYo88ue/qzBsRC8JAVzG0=";
  };

  dependencies = [ beautifulsoup4 ];

  meta = with lib; {
    description = "Audi Connect integration for Home Assistant";
    changelog = "https://github.com/audiconnect/audi_connect_ha/releases/tag/v${version}";
    homepage = "https://github.com/audiconnect/audi_connect_ha";
    license = licenses.mit;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
