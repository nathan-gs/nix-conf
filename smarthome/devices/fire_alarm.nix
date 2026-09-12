map
  (v: v // {
    type = "fire_alarm";
    homeassistant = { expire_after = null; };
    # z2m defaults battery devices to availability.passive.timeout = 1500min (25h),
    # which let a dead smoke alarm go unnoticed for two days. Both the Twinguard and
    # the BSD-2 check in every 27min (checkinInterval 1620s), so 90min is three
    # missed check-ins: quick enough to matter, loose enough not to cry wolf.
    availability = { timeout = 90; };
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
