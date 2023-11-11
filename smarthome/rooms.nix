let 
  floor0 = ["living" "keuken" "bureau"];
  floor1 = ["fen" "nikolai" "morgane" "badkamer"];
  basement = ["basement"];
in
{
  floor0 = floor0;
  floor1 = floor1;
  basement = basement;

  all = map(v: "floor0_${v}") floor0 ++ map(v: "floor1_${v}") floor1;
}