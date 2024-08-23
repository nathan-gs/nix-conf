{ config, lib, pkgs, ha, ... }:

{
  services.home-assistant.config = {
    recorder.exclude = {
      domains = [
        "automation"
        "media_player"
      ];
      event_types = [
        "call_service"
        "entity_registry_updated"
        "component_loaded"
        "service_registered"
        "recorder_5min_statistics_generated"
        "recorder_hourly_statistics_generated"
        "automation_triggered"
      ];
    };

  };
}
