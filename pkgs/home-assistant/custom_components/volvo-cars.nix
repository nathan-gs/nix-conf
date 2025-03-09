{
  lib,
  buildHomeAssistantComponent,
  fetchFromGitHub
}:

buildHomeAssistantComponent rec {
  owner = "thomasddn";
  domain = "volvo_cars";
  version = "1.4.3";

  src = fetchFromGitHub {
    inherit owner;
    inherit version;
    repo = "ha-volvo-cars";
    rev = "v${version}";
    hash = "sha256-0HcTSTtOUZzRyFbViuyr07FByRXCqA2SxvEU9zXWfRQ=";
  };

  dependencies = [ ];

  meta = with lib; {
    description = "Volvo Cars integration";
    changelog = "https://github.com/thomasddn/ha-volvo-cars/releases/tag/v${version}";
    homepage = "https://github.com/thomasddn/ha-volvo-cars";
    license = licenses.gpl3;
    maintainers = with maintainers; [ nathan-gs ];
  };
}