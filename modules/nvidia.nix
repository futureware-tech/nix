{
  pkgs,
  lib,
  config,
  ...
}:
let
  nvidiaDevices = builtins.filter (gpu: gpu.vendor == "nvidia") (
    builtins.attrValues config.fw.hardware.gpus.devices
  );

  nvidiaSmi = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";

  telegrafEnabled = config.services.telegraf.enable or false;
in
{
  imports = [ ./gpus.nix ];

  # NVIDIA side of fw.hardware.gpus. Whether a host needs it is not a separate
  # switch: it follows from the vendors of the cards listed in
  # fw.hardware.gpus.devices, so a host cannot claim an NVIDIA card and forget
  # to install the driver for it. The shared option declarations, pool
  # resolution and vendor-neutral tooling live in modules/gpus.nix.
  #
  # hasVendor is only ever set true while `enable` holds, so the `enable` test is
  # redundant on its own; keep both so the gate names the option it mirrors.
  config = lib.mkIf (config.fw.hardware.gpus.enable && config.fw.hardware.gpus.hasVendor.nvidia) {
    nixpkgs.config.nvidia.acceptLicense = true;
    hardware.nvidia-container-toolkit.enable = true;

    # Put the driver's own firmware onto the filesystem rather than falling back
    # to the version embedded into the kernel. linux-firmware itself, which holds
    # the gsp_ga10x.bin blob Ampere+ cards need to initialise, is enabled by
    # modules/gpus.nix.
    hardware.firmware = [ config.hardware.nvidia.package.firmware ];

    hardware.nvidia = {
      datacenter.enable = true;
      open = false; # More stable for Ampere.

      powerManagement.enable = false;
      # Keep NVIDIA drivers always loaded to control GPU P-states and save power when idle
      nvidiaPersistenced = true;

      # Disable unused tools.
      modesetting.enable = false;
      nvidiaSettings = false;
    };

    # Disable NVLink: unused, and fails to start, breaking deploy.
    systemd.services.nvidia-fabricmanager.enable = lib.mkForce false;

    systemd.services.nvidia-power-limit = {
      description = "Set NVIDIA GPU power limits";
      wantedBy = [ "multi-user.target" ];
      after = [ "nvidia-persistenced.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script =
        let
          limits = builtins.filter (gpu: gpu.powerLimit != null) nvidiaDevices;
        in
        if limits == [ ] then
          "true"
        else
          lib.concatStringsSep "\n" (
            map (gpu: ''
              ${nvidiaSmi} -i ${gpu.uuid} -pl ${toString gpu.powerLimit} || true
            '') limits
          );
    };

    services.telegraf = lib.mkIf telegrafEnabled {
      extraConfig.inputs = {
        nvidia_smi.bin_path = nvidiaSmi;
        # Workaround: Telegraf's nvidia_smi plugin does not yet emit
        # clocks_event_reasons_counters (see
        # https://github.com/influxdata/telegraf/issues/19404). Query them
        # directly via nvidia-smi CSV output using the exact same measurement
        # and field names as the native plugin.
        # Remove this workaround when the upstream fix is deployed in Telegraf.
        exec = [
          {
            commands = [
              "${pkgs.writeShellScript "nvidia-throttle-counters" ''
                ${nvidiaSmi} \
                  --query-gpu=index,uuid,name,clocks_event_reasons_counters.sw_thermal_slowdown,clocks_event_reasons_counters.hw_thermal_slowdown,clocks_event_reasons_counters.sw_power_cap,clocks_event_reasons_counters.hw_power_brake_slowdown,clocks_event_reasons_counters.sync_boost \
                  --format=csv,noheader,nounits | ${pkgs.gnused}/bin/sed 's/\[N\/A\]/0/g'
              ''}"
            ];
            data_format = "csv";
            csv_header_row_count = 0;
            csv_column_names = [
              "index"
              "uuid"
              "name"
              "clocks_event_reasons_counters_sw_thermal_slowdown"
              "clocks_event_reasons_counters_hw_thermal_slowdown"
              "clocks_event_reasons_counters_sw_power_cap"
              "clocks_event_reasons_counters_hw_power_brake_slowdown"
              "clocks_event_reasons_counters_sync_boost"
            ];
            csv_column_types = [
              "string"
              "string"
              "string"
              "int"
              "int"
              "int"
              "int"
              "int"
            ];
            csv_tag_columns = [
              "index"
              "uuid"
              "name"
            ];
            csv_trim_space = true;
            name_override = "nvidia_smi";
          }
        ];
      };
    };

    systemd.services.telegraf = lib.mkIf telegrafEnabled {
      path = [ config.hardware.nvidia.package.bin ];
    };
  };
}
