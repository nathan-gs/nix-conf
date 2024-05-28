[
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6152/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_linkeroever_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6151/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_linkeroever_black_carbon'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10897/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_linkeroever_benzene'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10841/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_linkeroever_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/100008/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_linkeroever_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10954/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_rieme_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10953/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_rieme_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6487/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_benzene'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6619/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_carbon_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''carbon_dioxide'';
      unit_of_measurement = ''ppm'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99939/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_wind_direction'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6621/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6620/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_sulphur_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10607/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_black_carbon'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99941/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6622/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6625/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_ozone'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10794/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99940/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_wind_speed_scalar'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6627/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/6626/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_uccle_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10821/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10968/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7039/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10990/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_atmospheric_pressure'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99997/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7040/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7042/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10875/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7041/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_moerkerke_ozone'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7062/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_idegem_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7064/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_idegem_ozone'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7063/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_idegem_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7087/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99906/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_wind_direction'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7078/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_ozone'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7080/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_benzene'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7071/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carbon_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''carbon_monoxide'';
      unit_of_measurement = ''ppm'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7073/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7072/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_sulphur_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7086/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7074/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10602/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_black_carbon'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10878/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10796/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99907/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_wind_speed_scalar'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99908/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10976/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10998/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_atmospheric_pressure'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10703/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10879/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10702/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10823/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10705/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10704/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10706/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_carlierlaan_black_carbon'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10952/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_gent_lange_violettestraat_black_carbon'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10824/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7089/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/99998/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7091/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_ozone'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10880/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7090/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10970/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10992/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_atmospheric_pressure'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7092/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_destelbergen_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7095/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_wondelgem_sulphur_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7097/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_wondelgem_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7096/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_wondelgem_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7103/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_sulphur_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10825/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7105/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7104/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7107/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7106/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10881/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10971/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10993/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_evergem_atmospheric_pressure'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7110/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7111/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10826/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7115/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_ozone'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''ozone'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7117/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7109/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_sulphur_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10882/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10752/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10972/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10994/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_sint_kruiswinkel_atmospheric_pressure'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7121/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7120/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_sulphur_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''sulphur_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7122/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7125/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_pm10'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm10'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10605/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_black_carbon'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10827/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_humidity'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''humidity'';
      unit_of_measurement = ''%'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/100012/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_pm25'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm25'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/7119/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_carbon_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''carbon_monoxide'';
      unit_of_measurement = ''ppm'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10883/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_pm1'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''pm1'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10973/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_temperature'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''temperature'';
      unit_of_measurement = ''°C'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10995/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_zelzate_atmospheric_pressure'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''atmospheric_pressure'';
      unit_of_measurement = ''mbar'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10750/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_wachtebeke_nitrogen_monoxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_monoxide'';
      unit_of_measurement = ''µg/m³'';
    }
    {
      resource = ''https://geo.irceline.be/sos/api/v1/timeseries/10751/getData'';
      scan_interval = 1800;
      platform = ''rest'';
      params.timespan = ''PT0H/{{ (now()).strftime('%Y-%m-%dT:%H:%M:%S') }}'';
      params.force_latest_value = true;
      name = ''irceline_inner_wachtebeke_nitrogen_dioxide'';
      value_template = ''{{ value_json["values"][0]["value"] }}'';
      json_attributes_path = ''$.values.[0]'';
      json_attributes = ["timestamp"];
      device_class = ''nitrogen_dioxide'';
      unit_of_measurement = ''µg/m³'';
    }
]
