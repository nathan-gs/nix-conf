map
  (v: v // {
    type = "plug";
    homeassistant.child_lock = null;
  })
  [
    {
      zone = "garden";
      name = "laadpaal";
      ieee = "0x842e14fffe3b8777";
      floor = "garden";
    }
    {
      zone = "living";
      name = "sonos_rear";
      ieee = "0x5c0272fffe88e39f";
      floor = "floor0";
    }
    {
      zone = "garden";
      name = "pomp";
      ieee = "0x9035eafffeb237bb";
      floor = "garden";
    }
  ]
