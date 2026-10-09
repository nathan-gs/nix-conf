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
      #
      # 1500min (25h) is z2m's own default for battery devices, and a deliberate
      # exception to the 90min used for the Bosch units. This device does not
      # self-report: measured 2026-09-14/15 it went 5.5h and then 21h without
      # sending anything, and every lastSeen update came from something poking it.
      # Any shorter timeout just flaps. The poke is the smoke read in
      # smarthome/air_quality/fire_alarm.nix: once a day, and again when this
      # device goes offline. The timeout stays long so a missed read shows up as
      # offline instead of the availability bit flapping on its own.
      #
      # The risk is bounded because the detection chamber and local buzzer are
      # autonomous hardware: smoke in the attic sounds this device whatever Zigbee,
      # the NIKO or HA are doing. What a long timeout delays is notice that the
      # *linkage* has degraded, and linkage here is a best-effort enhancement, not
      # a certified interconnect. Commanding it still works - verified 2026-09-14,
      # it sounded with the other three inside the 15s test window.
      zone = "hallway";
      name = "main";
      ieee = "0x54ef441001313d40";
      floor = "floor2";
      availability = { timeout = 1500; };
    }
  ]
