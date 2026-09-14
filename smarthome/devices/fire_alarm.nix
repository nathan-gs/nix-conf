map
  (v:
    # z2m defaults battery devices to availability.passive.timeout = 1500min (25h),
    # which let a dead smoke alarm go unnoticed for two days. Aim for roughly three
    # missed check-ins instead: quick enough to matter, loose enough not to cry
    # wolf. Both Bosch models check in every 27min (checkinInterval 1620s), hence
    # 90min. Devices that check in less often set their own value below.
    { availability = { timeout = 90; }; }
    // v
    // {
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
    {
      # Aqara JY-GZ-01AQ (sold as SD-S01E; reports lumi.sensor_smoke.acn03).
      # Checks in hourly rather than the Bosch 27min, so 90min would cry wolf -
      # 200min keeps the same ~3 missed check-ins of margin.
      zone = "attic";
      name = "main";
      ieee = "0x54ef441001313d40";
      floor = "attic";
      availability = { timeout = 200; };
    }
  ]
