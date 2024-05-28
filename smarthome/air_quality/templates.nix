[
    {
      name = ''irceline_linkeroever_pm10'';
      state = ''{{ states('sensor.irceline_inner_linkeroever_pm10') }}'';
      attributes.latitude = ''51.23619419990248'';
      attributes.longitude = ''4.385223684454717'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_linkeroever_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_linkeroever_black_carbon'';
      state = ''{{ states('sensor.irceline_inner_linkeroever_black_carbon') }}'';
      attributes.latitude = ''51.23619419990248'';
      attributes.longitude = ''4.385223684454717'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_linkeroever_black_carbon', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_linkeroever_benzene'';
      state = ''{{ states('sensor.irceline_inner_linkeroever_benzene') }}'';
      attributes.latitude = ''51.23619419990248'';
      attributes.longitude = ''4.385223684454717'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_linkeroever_benzene', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_linkeroever_pm1'';
      state = ''{{ states('sensor.irceline_inner_linkeroever_pm1') }}'';
      attributes.latitude = ''51.23619419990248'';
      attributes.longitude = ''4.385223684454717'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_linkeroever_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_linkeroever_pm25'';
      state = ''{{ states('sensor.irceline_inner_linkeroever_pm25') }}'';
      attributes.latitude = ''51.23619419990248'';
      attributes.longitude = ''4.385223684454717'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_linkeroever_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_rieme_pm25'';
      state = ''{{ states('sensor.irceline_inner_rieme_pm25') }}'';
      attributes.latitude = ''51.174053838769616'';
      attributes.longitude = ''3.7860846523965317'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_rieme_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_rieme_pm10'';
      state = ''{{ states('sensor.irceline_inner_rieme_pm10') }}'';
      attributes.latitude = ''51.174053838769616'';
      attributes.longitude = ''3.7860846523965317'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_rieme_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_benzene'';
      state = ''{{ states('sensor.irceline_inner_zelzate_benzene') }}'';
      attributes.latitude = ''51.20314142607233'';
      attributes.longitude = ''3.8084003239516524'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_benzene', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_carbon_dioxide'';
      state = ''{{ states('sensor.irceline_inner_uccle_carbon_dioxide') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_carbon_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''carbon_dioxide'';
      unit_of_measurement = ''ppm'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_wind_direction'';
      state = ''{{ states('sensor.irceline_inner_uccle_wind_direction') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_wind_direction', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_uccle_nitrogen_monoxide') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_sulphur_dioxide'';
      state = ''{{ states('sensor.irceline_inner_uccle_sulphur_dioxide') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_sulphur_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_black_carbon'';
      state = ''{{ states('sensor.irceline_inner_uccle_black_carbon') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_black_carbon', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_temperature'';
      state = ''{{ states('sensor.irceline_inner_uccle_temperature') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_uccle_nitrogen_dioxide') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_ozone'';
      state = ''{{ states('sensor.irceline_inner_uccle_ozone') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_ozone', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_humidity'';
      state = ''{{ states('sensor.irceline_inner_uccle_humidity') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_wind_speed_scalar'';
      state = ''{{ states('sensor.irceline_inner_uccle_wind_speed_scalar') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_wind_speed_scalar', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_pm25'';
      state = ''{{ states('sensor.irceline_inner_uccle_pm25') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_uccle_pm10'';
      state = ''{{ states('sensor.irceline_inner_uccle_pm10') }}'';
      attributes.latitude = ''50.79664962465285'';
      attributes.longitude = ''4.358623958109107'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_uccle_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_humidity'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_humidity') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_temperature'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_temperature') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_atmospheric_pressure'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_atmospheric_pressure') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_atmospheric_pressure', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_pm25'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_pm25') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_pm10'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_pm10') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_pm1'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_pm1') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_moerkerke_ozone'';
      state = ''{{ states('sensor.irceline_inner_moerkerke_ozone') }}'';
      attributes.latitude = ''51.25457362243645'';
      attributes.longitude = ''3.3625358887015975'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_moerkerke_ozone', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_idegem_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_idegem_nitrogen_monoxide') }}'';
      attributes.latitude = ''50.79891560368916'';
      attributes.longitude = ''3.930293237601761'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_idegem_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_idegem_ozone'';
      state = ''{{ states('sensor.irceline_inner_idegem_ozone') }}'';
      attributes.latitude = ''50.79891560368916'';
      attributes.longitude = ''3.930293237601761'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_idegem_ozone', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_idegem_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_idegem_nitrogen_dioxide') }}'';
      attributes.latitude = ''50.79891560368916'';
      attributes.longitude = ''3.930293237601761'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_idegem_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_pm25'';
      state = ''{{ states('sensor.irceline_inner_gent_pm25') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_wind_direction'';
      state = ''{{ states('sensor.irceline_inner_gent_wind_direction') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_wind_direction', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_ozone'';
      state = ''{{ states('sensor.irceline_inner_gent_ozone') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_ozone', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_benzene'';
      state = ''{{ states('sensor.irceline_inner_gent_benzene') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_benzene', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carbon_monoxide'';
      state = ''{{ states('sensor.irceline_inner_gent_carbon_monoxide') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carbon_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''carbon_monoxide'';
      unit_of_measurement = ''ppm'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_gent_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_sulphur_dioxide'';
      state = ''{{ states('sensor.irceline_inner_gent_sulphur_dioxide') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_sulphur_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_pm10'';
      state = ''{{ states('sensor.irceline_inner_gent_pm10') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_gent_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_black_carbon'';
      state = ''{{ states('sensor.irceline_inner_gent_black_carbon') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_black_carbon', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_pm1'';
      state = ''{{ states('sensor.irceline_inner_gent_pm1') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_humidity'';
      state = ''{{ states('sensor.irceline_inner_gent_humidity') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_wind_speed_scalar'';
      state = ''{{ states('sensor.irceline_inner_gent_wind_speed_scalar') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_wind_speed_scalar', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_temperature'';
      state = ''{{ states('sensor.irceline_inner_gent_temperature') }}'';
      attributes.latitude = ''51.058331716264874'';
      attributes.longitude = ''3.729298171690584'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_temperature'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_temperature') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_atmospheric_pressure'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_atmospheric_pressure') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_atmospheric_pressure', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_pm1'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_pm1') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_humidity'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_humidity') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_pm25'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_pm25') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_pm10'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_pm10') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_carlierlaan_black_carbon'';
      state = ''{{ states('sensor.irceline_inner_gent_carlierlaan_black_carbon') }}'';
      attributes.latitude = ''51.04068941942753'';
      attributes.longitude = ''3.734971479685305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_carlierlaan_black_carbon', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_gent_lange_violettestraat_black_carbon'';
      state = ''{{ states('sensor.irceline_inner_gent_lange_violettestraat_black_carbon') }}'';
      attributes.latitude = ''51.046879295386944'';
      attributes.longitude = ''3.734274548131827'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_gent_lange_violettestraat_black_carbon', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_humidity'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_humidity') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_pm25'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_pm25') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_ozone'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_ozone') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_ozone', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_pm1'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_pm1') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_temperature'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_temperature') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_atmospheric_pressure'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_atmospheric_pressure') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_atmospheric_pressure', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
      state_class = "measurement";
    }
    {
      name = ''irceline_destelbergen_pm10'';
      state = ''{{ states('sensor.irceline_inner_destelbergen_pm10') }}'';
      attributes.latitude = ''51.06127769765467'';
      attributes.longitude = ''3.7752623896453574'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_destelbergen_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_wondelgem_sulphur_dioxide'';
      state = ''{{ states('sensor.irceline_inner_wondelgem_sulphur_dioxide') }}'';
      attributes.latitude = ''51.088957723664365'';
      attributes.longitude = ''3.7161193706960174'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_wondelgem_sulphur_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_wondelgem_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_wondelgem_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.088957723664365'';
      attributes.longitude = ''3.7161193706960174'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_wondelgem_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_wondelgem_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_wondelgem_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.088957723664365'';
      attributes.longitude = ''3.7161193706960174'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_wondelgem_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_sulphur_dioxide'';
      state = ''{{ states('sensor.irceline_inner_evergem_sulphur_dioxide') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_sulphur_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_humidity'';
      state = ''{{ states('sensor.irceline_inner_evergem_humidity') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_evergem_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_evergem_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_pm25'';
      state = ''{{ states('sensor.irceline_inner_evergem_pm25') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_pm10'';
      state = ''{{ states('sensor.irceline_inner_evergem_pm10') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_pm1'';
      state = ''{{ states('sensor.irceline_inner_evergem_pm1') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_temperature'';
      state = ''{{ states('sensor.irceline_inner_evergem_temperature') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_evergem_atmospheric_pressure'';
      state = ''{{ states('sensor.irceline_inner_evergem_atmospheric_pressure') }}'';
      attributes.latitude = ''51.12469051189999'';
      attributes.longitude = ''3.739504220441925'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_evergem_atmospheric_pressure', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_humidity'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_humidity') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_ozone'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_ozone') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_ozone', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_pm10'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_pm10') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_sulphur_dioxide'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_sulphur_dioxide') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_sulphur_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_pm1'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_pm1') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_pm25'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_pm25') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_temperature'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_temperature') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_sint_kruiswinkel_atmospheric_pressure'';
      state = ''{{ states('sensor.irceline_inner_sint_kruiswinkel_atmospheric_pressure') }}'';
      attributes.latitude = ''51.15013609000081'';
      attributes.longitude = ''3.80873543041274'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_sint_kruiswinkel_atmospheric_pressure', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_zelzate_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_sulphur_dioxide'';
      state = ''{{ states('sensor.irceline_inner_zelzate_sulphur_dioxide') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_sulphur_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_zelzate_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_pm10'';
      state = ''{{ states('sensor.irceline_inner_zelzate_pm10') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_pm10', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_black_carbon'';
      state = ''{{ states('sensor.irceline_inner_zelzate_black_carbon') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_black_carbon', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_humidity'';
      state = ''{{ states('sensor.irceline_inner_zelzate_humidity') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_humidity', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_pm25'';
      state = ''{{ states('sensor.irceline_inner_zelzate_pm25') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_pm25', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_carbon_monoxide'';
      state = ''{{ states('sensor.irceline_inner_zelzate_carbon_monoxide') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_carbon_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''carbon_monoxide'';
      unit_of_measurement = ''ppm'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_pm1'';
      state = ''{{ states('sensor.irceline_inner_zelzate_pm1') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_pm1', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_temperature'';
      state = ''{{ states('sensor.irceline_inner_zelzate_temperature') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_temperature', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
      state_class = "measurement";
    }
    {
      name = ''irceline_zelzate_atmospheric_pressure'';
      state = ''{{ states('sensor.irceline_inner_zelzate_atmospheric_pressure') }}'';
      attributes.latitude = ''51.19606326849932'';
      attributes.longitude = ''3.8229200468043305'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_zelzate_atmospheric_pressure', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
      state_class = "measurement";
    }
    {
      name = ''irceline_wachtebeke_nitrogen_monoxide'';
      state = ''{{ states('sensor.irceline_inner_wachtebeke_nitrogen_monoxide') }}'';
      attributes.latitude = ''51.176100104067444'';
      attributes.longitude = ''3.869928172752206'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_wachtebeke_nitrogen_monoxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
    {
      name = ''irceline_wachtebeke_nitrogen_dioxide'';
      state = ''{{ states('sensor.irceline_inner_wachtebeke_nitrogen_dioxide') }}'';
      attributes.latitude = ''51.176100104067444'';
      attributes.longitude = ''3.869928172752206'';
      attributes.timestamp = ''{{ ((state_attr('sensor.irceline_inner_wachtebeke_nitrogen_dioxide', 'timestamp') | float) / 1000) | timestamp_custom('%Y-%m-%dT%H:%M:%SZ') }}'';
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
      state_class = "measurement";
    }
]
