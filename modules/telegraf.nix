{
  pkgs,
  config,
  lib,
  ...
}:
{
  services.telegraf = {
    enable = true;
    extraConfig = {
      agent = {
        hostname = config.networking.fqdn;
        metric_buffer_limit = 40000;
        collection_jitter = "1s";
      };
      outputs = {
        prometheus_client = {
          # Do not set port here, as some host may prefer to hide it behind a
          # reverse proxy. Secure by default.
          metric_version = 2;
          # Maintain persistent HTTP keep-alive connections across Prometheus scrapes (e.g. 15s intervals).
          # Default is 10s which forces premature TCP teardown and frequent reconnects.
          read_timeout = "60s";
          write_timeout = "60s";
        };
      };
      inputs = {
        # System
        kernel = { };
        processes = { };
        system = { };
        linux_sysctl_fs = { };

        # CPU
        interrupts = {
          cpu_as_tag = true;
        };
        cpu = {
          percpu = true;
          totalcpu = true;
          collect_cpu_time = false;
          report_active = false;
          core_tags = false;
        };

        # Memory
        mem = { };
        swap = { };

        # Storage
        disk = {
          ignore_fs = [
            "tmpfs"
            "devtmpfs"
            "devfs"
            "iso9660"
            "overlay"
            "aufs"
            "squashfs"
            "bindfs"
          ];
        };
        diskio = { };
        zfs = {
          poolMetrics = true;
          datasetMetrics = true;
        };
        smart = { };

        # Network
        conntrack = { };
        ethtool = {
          interface_exclude = [
            "*vlan*"
            "docker*"
            "br*"
            "mac*" # macvlan/macvtap from incus VMs
            "wlan*"
          ];
        };
        net = { };
        netstat = { };
        nstat = {
          dump_zeros = true;
        };

        # Hardware misc
        sensors = {
          remove_numbers = false;
        };
        temp = { };

        internal = { };
      }
      // lib.optionalAttrs (config.fw.hardware.gpus.enable or false) {
        nvidia_smi = { };
      };
    };
  };

  systemd.services.telegraf.path = [
    pkgs.lm_sensors
    pkgs.smartmontools
    pkgs.nvme-cli
  ]
  ++ lib.optional (config.fw.hardware.gpus.enable or false) config.hardware.nvidia.package.bin;

  users.users.telegraf.extraGroups = [ "disk" ];
}
