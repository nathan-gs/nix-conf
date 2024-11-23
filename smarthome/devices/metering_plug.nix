map
  (v: v // {
    type = "metering_plug";
    homeassistant.child_lock = null;
  })
  [
    {
      zone = "waskot";
      name = "droogkast";
      ieee = "0xa4c138163459950e";
      floor = "floor1";
    }
    {
      zone = "keuken";
      name = "oven";
      ieee = "0xa4c1381f8ccf7230";
      floor = "floor0";
    }
    {
      zone = "basement";
      name = "network";
      ieee = "0xa4c138ae189cf8bd";
      floor = "basement";
    }
    {
      zone = "waskot";
      name = "wasmachine";
      ieee = "0xa4c1383c42598ec3";
      floor = "floor1";
    }
    {
      zone = "bureau";
      name = "pc";
      ieee = "0xa4c138a029d5a884";
      floor = "floor0";
    }
    {
      zone = "badkamer";
      name = "verwarming";
      ieee = "0xa4c138fd75fc9f62";
      floor = "floor1";
    }
    {
      zone = "nikolai";
      name = "verwarming";
      ieee = "0xa4c138ed6a249389";      
      floor = "floor1";
    }
    {
      zone = "bureau";
      name = "verwarming";
      ieee = "0xa4c1388319da7258";
      floor = "floor0";
    }
    {
      zone = "living";
      name = "verwarming";
      ieee = "0xa4c138689a501455";
      floor = "floor0";
    }
    {
      zone = "wtw";
      name = "verwarming";
      ieee = "0xa4c138bd3c10d7c4";
      floor = "system";
    }
    {
      zone = "wtw";
      name = "wtw";
      ieee = "0xa4c1389e32839e0e";
      floor = "system";
    }
    {
      zone = "doorbell";
      name = "doorbell";
      ieee = "0xa4c138fde84ee814";
      floor = "system";
    }
    {
      zone = "nikolai";
      name = "scherm";
      ieee = "0xa4c138947648ed30";
      floor = "floor1";
    }
    {
      zone = "fen";
      name = "deken";
      ieee = "0xa4c138f0231a1d4f";
      floor = "floor1";
    }
    {
      zone = "keuken";
      name = "airfryer";
      ieee = "0xa4c13863b0b63bf6";
      floor = "floor0";
    }
    {
      zone = "basement";
      name = "diepvries";
      ieee = "0xa4c13831f438c2ea";
      floor = "basement";
    }
  ]

# Devices with issues:
#
# 0xa4c1385317a3b396 incorrect measurement