{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {
    recorder.exclude = {
      domains = [
        "media_player"
      ];
      event_types = [
        "call_service"
        "entity_registry_updated"
        "component_loaded"
        "service_registered"
        "recorder_5min_statistics_generated"
        "recorder_hourly_statistics_generated"
      ];
    };

  };
}
