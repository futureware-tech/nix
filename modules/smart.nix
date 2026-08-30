_: {
  services.smartd =
    let
      # -a: monitor all attributes
      # -o: run automatic offline test on startup
      # -S: attribute autosave
      # -T: still monitor devices with failed SMART commands
      # -W: DIFF,INFO,CRIT temperature thresholds.
      #     Use -W 10,65,70 for SSD.
      # -n: powermode
      # -s: test schedule: "type/MM/DD/dow/HH"
      # Short: Sunday (7), 22:00 UTC
      # Long: 1st of month, 23:00 UTC
      opts = "-a -o on -S on -T permissive -W 5,45,50 -n never,q -s (S/../../7/22|L/../01/./23)";
    in
    {
      enable = true;
      defaults.autodetected = opts;
      defaults.monitored = opts;
    };
}
