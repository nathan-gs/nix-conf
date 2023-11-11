{ config, lib, pkgs, ... }:

{
  services.home-assistant.config = {
    afvalbeheer = {
      wastecollector = "RecycleApp";
      upcomingsensor = 1;
      printwastetypes = 0;
      postcode = config.secrets.address.zip;
      streetname = config.secrets.address.street;
      streetnumber = config.secrets.address.streetNumber;
      resources = [
        "gft" "glas" "grofvuil" "papier" "pmd" "restafval"
      ];
    };
  };
}
