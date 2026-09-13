# Alerting on top of services/server-health2mqtt.nix.
#
# The per-metric entities are created by MQTT discovery published by each
# server, so nothing here enumerates hosts or disks: the templates below find
# the problem sensors by entity-id shape. Add a disk (or a whole host) and it
# starts alerting with no change to this file.
#
# Entity ids come from the discovery object_id, e.g.
#   binary_sensor.system_network_server_nnas_problem
#   binary_sensor.system_network_server_nnas_disk_zct3qstm_problem
#   binary_sensor.system_network_server_nnas_btrfs_problem
#   sensor.system_network_server_nnas_problem_count        <- host tier only
#
# The two aggregates below are named "servers" (plural) on purpose: the
# discovery regex matches "system_network_server_", so a singular name would
# make each aggregate match itself and count its own state.
#
# Two distinct failures, deliberately kept apart:
#   .problem      — a server told us something is wrong.
#   .unreachable  — a server stopped telling us anything (its host-tier
#                   entities expired). This is the case the monthly email
#                   could never cover, and it is the more urgent of the two.
{ config, lib, pkgs, ha, ... }:
let
  # Host-tier problem_count entities only: the per-disk and per-btrfs ones
  # carry an extra path segment, and hostnames here contain no underscore.
  hostCountEntities = ''
    {% set hosts = states.sensor
         | selectattr('entity_id','search','^sensor\\.system_network_server_[^_]+_problem_count$')
         | list %}
  '';

  # Every problem binary_sensor across all servers (host, disks, btrfs).
  problemEntities = ''
    {% set problems = states.binary_sensor
         | selectattr('entity_id','search','^binary_sensor\\.system_network_server_')
         | selectattr('attributes.device_class','defined')
         | selectattr('attributes.device_class','eq','problem')
         | list %}
  '';

  # "<host> <what>: <problem>" lines, pulled from the `problems` attribute the
  # publisher puts on each problem sensor.
  problemLines = ''
    ${problemEntities}
    {% set ns = namespace(lines=[]) %}
    {% for e in problems if e.state == 'on' %}
      {% set name = e.entity_id
           | replace('binary_sensor.system_network_server_',"")
           | replace('_problem',"") %}
      {% for p in (e.attributes.problems | default([])) %}
        {% set ns.lines = ns.lines + [name ~ ': ' ~ p] %}
      {% endfor %}
      {% if (e.attributes.problems | default([])) | length == 0 %}
        {% set ns.lines = ns.lines + [name ~ ': problem'] %}
      {% endif %}
    {% endfor %}
  '';
in
{
  services.home-assistant.config = {

    template = [
      {
        binary_sensor = [
          {
            name = "system/network/servers.problem";
            unique_id = "system_network_servers_problem";
            device_class = "problem";
            state = ''
              ${problemEntities}
              {{ problems | selectattr('state','eq','on') | list | count > 0 }}
            '';
            attributes = {
              problems = ''
                ${problemLines}
                {{ ns.lines }}
              '';
              problem_count = ''
                ${problemLines}
                {{ ns.lines | count }}
              '';
            };
          }
          {
            # expire_after on the host-tier entities turns "host went quiet"
            # into unavailable; that is the signal here.
            name = "system/network/servers.unreachable";
            unique_id = "system_network_servers_unreachable";
            device_class = "connectivity";
            state = ''
              ${hostCountEntities}
              {{ hosts | rejectattr('state','in',['unavailable','unknown'])
                       | list | count == hosts | count and hosts | count > 0 }}
            '';
            attributes.unreachable = ''
              ${hostCountEntities}
              {{ hosts | selectattr('state','in',['unavailable','unknown'])
                       | map(attribute='entity_id')
                       | map('replace','sensor.system_network_server_',"")
                       | map('replace','_problem_count',"")
                       | list }}
            '';
          }
        ];
      }
    ];

    automation = [
      # 30m of sustained problem: long enough to ride out a reboot or a switch
      # restarting units, short enough to matter for a failing disk.
      (ha.automation "system/network/server.problem.notify" {
        triggers = [
          (ha.trigger.on_for "binary_sensor.system_network_servers_problem" "00:30:00")
        ];
        actions = [
          (ha.action.notify "Server health"
            ''
              {{ state_attr('binary_sensor.system_network_servers_problem','problems')
                 | join('\n') }}
            '')
        ];
      })

      # A server that stopped reporting. No `for:` beyond the expiry window
      # itself — expire_after already is the grace period.
      (ha.automation "system/network/server.unreachable.notify" {
        triggers = [
          (ha.trigger.off_for "binary_sensor.system_network_servers_unreachable" "00:10:00")
        ];
        actions = [
          (ha.action.notify "Server unreachable"
            ''
              No health data from: {{
                state_attr('binary_sensor.system_network_servers_unreachable','unreachable')
                | join(', ') }}
            '')
        ];
      })
    ];
  };
}
