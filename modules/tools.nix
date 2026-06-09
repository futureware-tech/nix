{
  lib,
  options,
  pkgs,
  ...
}:

let
  htopSettings = {
    # Header
    header_margin = false;
    detailed_cpu_time = true;
    show_cpu_frequency = true;
    show_cpu_temperature = true;
    column_meters_0 = "CPU Memory Swap DiskIO";
    column_meter_modes_0 = "1 1 1 2";
    column_meters_1 = "Tasks LoadAverage Uptime NetworkIO";
    column_meter_modes_1 = "2 2 2 2";

    # Tabs
    "screen:1_Main" =
      "PID USER PRIORITY NICE M_VIRT M_RESIDENT M_SHARE STATE PERCENT_CPU PERCENT_MEM TIME Command";
    "screen:2_IO" =
      "PID USER IO_PRIORITY IO_RATE IO_READ_RATE IO_WRITE_RATE PERCENT_SWAP_DELAY PERCENT_IO_DELAY Command";

    # List
    hide_kernel_threads = true;
    hide_userland_threads = true;
    highlight_base_name = true;
    tree_view = true;
  };
  hasHtopOption = options ? programs.htop;
in
lib.mkMerge [
  {
    environment.systemPackages =
      with pkgs;
      [
        vim
        git
        jq
        file
        ripgrep

        mosh
        openssh

        # Nix
        nix-output-monitor # nix build -> nom build
        nvd
        nixfmt

        # Software debug
        tcpdump
        lsof
        ncdu
        nmap
        lnav
        wakeonlan

        # Hardware info and tunables
        smartmontools # smartctl
        usbutils # lsusb
        pciutils # lspci
      ]
      ++ lib.optionals pkgs.stdenv.isLinux [
        # Software debug
        iotop
        dool # dool --time --disk -D /dev/sde,/dev/sdf --top-bio --top-cpu --zfs-arc
        strace
        ltrace
        smem # smem -tkP nginx

        # Hardware info and tunables
        parted
        hdparm
        efivar
        efibootmgr
        sg3_utils # sg_unmap
        lm_sensors # sensors
        nvme-cli
        dmidecode
        ethtool
      ];
  }

  (lib.optionalAttrs hasHtopOption {
    programs.htop = {
      enable = true;
      settings = htopSettings;
    };
  })

  (lib.optionalAttrs (!hasHtopOption) {
    environment.systemPackages = [ pkgs.htop ];
    environment.etc."htoprc".text =
      let
        serialize =
          val:
          if lib.isBool val then
            (if val then "1" else "0")
          else if lib.isList val then
            lib.concatStringsSep " " val
          else
            toString val;
      in
      lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${serialize v}") htopSettings) + "\n";
  })
]
