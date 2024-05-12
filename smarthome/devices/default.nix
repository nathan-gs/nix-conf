let

  air_quality = import ./air_quality.nix;
  buttons = import ./buttons.nix;
  light_plugs = import ./light_plugs.nix;
  lights = import ./lights.nix;
  metering_plugs = import ./metering_plugs.nix;
  plugs = import ./plugs.nix;
  rtv = import ./rtv.nix;
  temperature = import ./temperature.nix;
  windows = import ./windows.nix;

in
[ ]
++ air_quality
++ buttons
++ light_plugs
++ lights
++ metering_plugs
++ plugs
++ rtv
++ temperature
++ windows