{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub,
  beautifulsoup4,
}:

buildHomeAssistantComponent rec {
  owner = "audiconnect";
  domain = "audiconnect";
  version = "2.2.0";

  src = fetchFromGitHub {
    inherit owner;
    repo = "audi_connect_ha";
    rev = "v${version}";
    hash = "sha256-e+vDsTRzjdRK8GLQ8uN/rn6+xqBAjxgx5lc/stA50lw=";
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
