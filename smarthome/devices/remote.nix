map
  (v: v // {
    type = "remote";
    homeassistant = {};
  })
  [
    {
      # Philips Hue dimmer (RWL022). Not placed in a room; firmware checks stay in z2m.
      zone = "roaming";
      name = "philips";
      ieee = "0x0017880109a53e85";
      floor = "roaming";
    }
  ]
