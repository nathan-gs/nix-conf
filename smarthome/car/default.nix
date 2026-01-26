{ config, lib, pkgs, ... }:
let
  carName = config.secrets.nathan-car.name;
in
{

  imports = [
    ./car_charger
  ];

}