#!/usr/bin/env bash

device="$1"
device_name="$(echo $2 | tr '[:upper:]' '[:lower:]')"

stats=$(btrfs device stats $device | cut -f2 -d '.')

IFS=$'\n'
for line in $stats;
do
  x="$(echo $line | xargs)"
  gauge="$(echo $x | cut -f1 -d ' ')"
  value="$(echo $x | cut -f2 -d ' ')"
  echo "btrfs_device_${gauge}{disk=\"$device_name\"} $value";
done
