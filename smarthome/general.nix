{
  template = [
    {
      trigger = {
        platform = "time_pattern";
        minutes = "/15";
      };
      binary_sensor = [
        {
          name = "is_workday";
          state = "{{ (now().weekday() < 5) }}";
        }
        {
          name = "is_anyone_home";
          state = "{{ states.person | selectattr('state','eq','home') | list | count > 0 }}";
          device_class = "occupancy";
        }
      ];
    }
  ];
}