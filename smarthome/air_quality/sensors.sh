#!/usr/bin/env bash

bbox='{"center": {"type": "Point","coordinates" : [51.15, 3.82]},"radius": 10 }'


stations_list=":linkeroever:rieme:uccle:moerkerke:idegem:gent:gent_carlierlaan:gent_lange_violettestraat:destelbergen:wondelgem:evergem:sint_kruiswinkel:zelzate:wachtebeke:"
device_class_list=":date:enum:timestamp:apparent_power:aqi:atmospheric_pressure:battery:carbon_monoxide:carbon_dioxide:current:data_rate:data_size:distance:duration:energy:energy_storage:frequency:gas:humidity:illuminance:irradiance:moisture:monetary:nitrogen_dioxide:nitrogen_monoxide:nitrous_oxide:ozone:ph:pm1:pm10:pm25:power_factor:power:precipitation:precipitation_intensity:pressure:reactive_power:signal_strength:sound_pressure:speed:sulphur_dioxide:temperature:volatile_organic_compounds:volatile_organic_compounds_parts:voltage:volume:volume_storage:water:weight:wind_speed:"

stations_request=`curl \
  -H "Content-Type: application/json" \
  -X GET \
  --silent \
  --data-urlencode "near=$bbox" \
  "https://geo.irceline.be/sos/api/v1/stations?expanded=true"`

by_station=`echo $stations_request | jq -c '.[] | {properties, geometry}' `

echo "[" > ./sensors.nix
echo "[" > ./templates.nix

IFS=$'\n'
for i in $by_station;
do
  label=`echo $i | jq -r '.properties.label'`
  longitude=`echo $i | jq -r '.geometry.coordinates | .[0]'`
  latitude=`echo $i | jq -r '.geometry.coordinates | .[1]'`

  location=`echo $label | sed 's/ - /|/' | cut -d'|' -f2 | xargs`
  location_id=`echo ${label,,} | sed 's/ - /|/' | cut -d'|' -f1 | xargs`

  sensor_prefix=`echo ${location,,} | sed 's/ /_/g' | sed 's/-/_/g' | sed 's/(//g' | sed 's/)//g' ` 
  #timeseries=`echo $i | jq -r '.properties.timeseries | to_entries | map(.key)'`
  #echo "$location: ($sensor_prefix) $latitude,$longitude $timeseries"

  if [[ ":$stations_list:" = *:$sensor_prefix:* ]]
  then    
    true
  else
    continue
  fi


  
  for ts in `echo $i | jq -c '.properties.timeseries | to_entries | .[]'`
  do
    ts_id=`echo $ts | jq -r '.key'`    
    phenomenon=`echo $ts | jq -r '.value.phenomenon.label'`
    phenomenon_normalized=`echo ${phenomenon,,} | sed 's/particulate matter < 10 µm/pm10/' | sed 's/particulate matter < 2.5 µm/pm25/' | sed 's/particulate matter < 1 µm/pm1/' | sed 's/ /_/g' | sed 's/(//g' | sed 's/)//g' `

    if [ "$phenomenon_normalized" = "temperature" ];
    then
      unit="°C"      
    elif [ "$phenomenon_normalized" = "relative_humidity" ];
    then
      phenomenon_normalized="humidity"
      unit="%"
    elif [ "$phenomenon_normalized" = "atmospheric_pressure" ];
    then
      unit="mbar"
    elif [ "$phenomenon_normalized" = "carbon_monoxide" ];
    then
      unit="ppm"
    elif [ "$phenomenon_normalized" = "carbon_dioxide" ];
    then
      unit="ppm"      
    else
      unit="µg/m³"
    fi


    
    
    if [[ ":$device_class_list:" = *:$phenomenon_normalized:* ]];    
    then 
      device_class_stmt="device_class = ''${phenomenon_normalized}'';"      
    else
      device_class_stmt=""
    fi

    #echo $ts
    #echo "  $ts_id $phenomenon_normalized $unit"

    sensor=$(cat << EOSENSOR
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/${ts_id}/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_${sensor_prefix}_${phenomenon_normalized}'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      $device_class_stmt
      unit_of_measurement = ''${unit}'';
    }
EOSENSOR
  )

  template=$(cat << EOSENSOR
    {
      name = ''irceline_${sensor_prefix}_${phenomenon_normalized}'';
      state = ''{{ states('sensor.irceline_inner_${sensor_prefix}_${phenomenon_normalized}') }}'';
      attributes.latitude = ''${latitude}'';
      attributes.longitude = ''${longitude}'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_${sensor_prefix}_${phenomenon_normalized}', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      $device_class_stmt
      unit_of_measurement = ''${unit}'';
      state_class = "measurement";
    }
EOSENSOR
  )

  #attributes.latitude = ''${latitude}'';
  #attributes.longitude = ''${longitude}'';
  #attributes.last_updated = ''{{ ((value_json["${ts_id}"]["values"][0]["timestamp"] | float) / 1000) | timestamp_custom('%Y:%m:%dT%H:%M:%SZ') }}'';

  echo "$sensor" >> ./sensors.nix
  echo "$template" >> ./templates.nix

  done

  
done

echo "]" >> ./sensors.nix
echo "]" >> ./templates.nix