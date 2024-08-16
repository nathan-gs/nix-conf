let

  air_quality = import ./air_quality.nix;
  buttons = import ./button.nix;
  light_plugs = import ./light_plug.nix;
  light_switch = import ./light_switch.nix;
  lights = import ./light.nix;
  metering_plugs = import ./metering_plug.nix;
  plugs = import ./plug.nix;
  rtv = import ./rtv.nix;
  temperature = import ./temperature.nix;
  windows = import ./window.nix;

in
[ ]
++ air_quality
++ buttons
++ light_plugs
++ lights
++ light_switch
++ metering_plugs
++ plugs
++ rtv
++ temperature
++ windows