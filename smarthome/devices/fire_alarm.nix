map
  (v: v // {
    type = "fire_alarm";
    homeassistant = { expire_after = null; };
  })
  [
    {
      zone = "living";
      name = "main";
      ieee = "0x000d6f00196fc58f";
      floor = "floor0";
    }
    {
      zone = "basement";
      name = "top";
      ieee = "0xf84477fffe0c62e1";
      floor = "basement";
    }
    {
      zone = "hallway";
      name = "main";
      ieee = "0x000d6f0019104455";
      floor = "floor1";
    }
  ]
