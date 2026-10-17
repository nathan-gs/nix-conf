{ lib, fetchFromGitHub, buildHomeAssistantComponent }:

buildHomeAssistantComponent rec {
  owner = "TommiG1";
  domain = "cupra_eu_data_act";
  version = "0.6.46";

  src = fetchFromGitHub {
    inherit owner;
    repo = "HA_VAG-EU-Data-Act";
    rev = "v${version}";
    hash = "sha256-3YhRYKh6BqkweprUhfBNBpc3sLvSbvUat8EnYYakz6Y=";
  };

  meta = with lib; {
    description = "Home Assistant integration for the VW Group EU Data Act portal.";
    homepage = "https://github.com/TommiG1/HA_VAG-EU-Data-Act";
    license = licenses.mit;
    maintainers = with maintainers; [ nathan-gs ];
  };
}
