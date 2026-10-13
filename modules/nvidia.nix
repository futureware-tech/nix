{
  pkgs,
  lib,
  config,
  ...
}:
let
  gpuDevices = builtins.attrValues config.fw.hardware.gpus.devices;

  nvidiaDevices = builtins.filter (gpu: gpu.vendor == "nvidia") gpuDevices;

  # A card's PCI address is an accident of which slot it sits in, and cards do get
  # moved, so anything that needs a bus address resolves it at boot rather than
  # storing one in the config, where it would silently rot.
  #
  # nvidia-smi is not usable for this: the kernel module may not be loaded yet, it
  # is a comparatively heavy process, and its `pci.bus_id` uses an 8-digit domain
  # like 00000000:05:00.0, which does not match /sys/bus/pci/devices. The proc
  # entries the driver publishes already give the address in the right form.
  #
  # amdgpu has no equivalent proc tree, but it does publish a stable unique_id per
  # card under /sys, which is what we store in place of an NVIDIA UUID.
  pciResolver = pkgs.writeShellApplication {
    name = "gpu-pci";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
    ];
    text = ''
      set -u

      declare -A id_to_pci=()

      for info in /proc/driver/nvidia/gpus/*/information; do
        [ -f "$info" ] || continue
        id="$(sed -n 's/^GPU UUID:[[:space:]]*//p' "$info")"
        bus="$(sed -n 's/^Bus Location:[[:space:]]*//p' "$info")"
        if [ -n "$id" ] && [ -n "$bus" ]; then
          id_to_pci["$id"]="$bus"
        fi
      done

      for dev in /sys/bus/pci/devices/*; do
        [ -f "$dev/unique_id" ] || continue
        case "$(readlink -f "$dev/driver" 2>/dev/null || true)" in
          */amdgpu) ;;
          *) continue ;;
        esac
        id="$(sed 's/[[:space:]]*$//' "$dev/unique_id")"
        if [ -n "$id" ]; then
          id_to_pci["$id"]="''${dev##*/}"
        fi
      done

      missing=0

      # report <name> <id>
      report() {
        local name="$1" id="$2"
        local pci="''${id_to_pci["$id"]:-}"
        if [ -z "$pci" ]; then
          echo "gpu-pci: $name ($id) is not present" >&2
          missing=1
          return
        fi
        printf '%s %s\n' "$name" "$pci"
      }

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: gpu: ''
          report ${lib.escapeShellArg name} ${lib.escapeShellArg gpu.uuid}
        '') config.fw.hardware.gpus.devices
      )}

      exit "$missing"
    '';
  };
in
{
  options.fw.hardware.gpus.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.fw.hardware.gpus.devices != { };
    description = "Enable GPU drivers and configuration for the cards listed in fw.hardware.gpus.devices";
  };

  options.fw.hardware.gpus.devices = lib.mkOption {
    description = "Attribute set of GPUs installed on this host";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          vendor = lib.mkOption {
            type = lib.types.enum [
              "nvidia"
              "amd"
            ];
            default = "nvidia";
            description = "Which vendor made the card; decides how it is identified and which tooling drives it";
          };
          uuid = lib.mkOption {
            type = lib.types.str;
            description = "Stable per-card identifier: the UUID from nvidia-smi, or the amdgpu sysfs unique_id for an AMD card";
          };
          model = lib.mkOption {
            type = lib.types.str;
            description = "Model name";
          };
          compute = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether this GPU's cudaCapability contributes to pool CUDA arches";
          };
          powerLimit = lib.mkOption {
            type = lib.types.nullOr lib.types.int;
            default = null;
          };
          cudaCapability = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "CUDA compute capability (e.g. '8.6')";
          };
        };
      }
    );
  };

  options.fw.hardware.gpus.pools = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = { };
    description = "Named GPU pools mapping to lists of device names in fw.hardware.gpus.devices";
  };

  options.fw.hardware.gpus.resolvedPools = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          devices = lib.mkOption {
            type = lib.types.listOf lib.types.attrs;
            description = "Device submodules in this pool";
          };
          uuids = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of UUIDs of the GPUs in this pool";
          };
          environment = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            description = "Environment variables for this pool (CUDA_VISIBLE_DEVICES, NVIDIA_VISIBLE_DEVICES)";
          };
          cudaCapabilities = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "CUDA capabilities of the compute GPUs for this pool";
          };
          requiredArches = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "CUDA real architectures required for this pool";
          };
          needsRebuild = lib.mkOption {
            type = lib.types.bool;
            description = "True if the required capabilities are not in the default Nixpkgs arches";
          };
          applyCudaArches = lib.mkOption {
            type = lib.types.functionTo lib.types.package;
            description = "Function to apply cudaArches overrides to a package if needed";
          };
        };
      }
    );
    default = { };
    description = "Resolved pool attributes (environment, capabilities, build overrides)";
  };

  options.fw.hardware.gpus.allCudaCapabilities = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "CUDA capabilities for all GPUs installed on this host (including compute=false, for stress testing/gpu-burn)";
  };

  options.fw.hardware.gpus.hasVendor = lib.mkOption {
    type = lib.types.attrsOf lib.types.bool;
    default = {
      nvidia = false;
      amd = false;
    };
    description = "Whether at least one configured GPU comes from each vendor";
  };

  options.fw.hardware.gpus.pciResolver = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    description = ''
      Script printing "<gpu-name> <pci-address>" for every configured GPU that is
      currently present, resolving each one by UUID. Exits non-zero if one is
      missing. Consumers include virtualisation stacks that can only select a
      physical device by bus address.
    '';
  };

  config = lib.mkIf config.fw.hardware.gpus.enable {
    fw.hardware.gpus.pciResolver = pciResolver;

    fw.hardware.gpus.hasVendor = lib.genAttrs [ "nvidia" "amd" ] (
      vendor: builtins.any (gpu: gpu.vendor == vendor) gpuDevices
    );

    fw.hardware.gpus.allCudaCapabilities = lib.unique (
      builtins.sort builtins.lessThan (
        builtins.filter (x: x != null) (map (gpu: gpu.cudaCapability) gpuDevices)
      )
    );

    fw.hardware.gpus.resolvedPools =
      let
        mkPool =
          _poolName: deviceNames:
          let
            gpus = builtins.map (name: config.fw.hardware.gpus.devices.${name}) deviceNames;

            uuids = builtins.sort builtins.lessThan (builtins.map (gpu: gpu.uuid) gpus);
            csv = builtins.concatStringsSep "," uuids;

            # Only GPUs with compute=true contribute their cudaCapability to build-time arches.
            computeGpus = builtins.filter (gpu: gpu.compute) gpus;
            caps = builtins.map (gpu: gpu.cudaCapability) computeGpus;
            cudaCapabilities = lib.unique (
              builtins.sort builtins.lessThan (builtins.filter (x: x != null) caps)
            );

            requiredArches = map pkgs._cuda.lib.mkRealArchitecture cudaCapabilities;
            defaultArches = pkgs.cudaPackages.flags.realArches or [ ];
            needsRebuild = builtins.any (arch: !(builtins.elem arch defaultArches)) requiredArches;
          in
          {
            devices = gpus;
            inherit uuids;
            environment = {
              CUDA_VISIBLE_DEVICES = csv;
              NVIDIA_VISIBLE_DEVICES = csv;
            };
            inherit cudaCapabilities requiredArches needsRebuild;
            applyCudaArches =
              pkg:
              if needsRebuild && requiredArches != [ ] then
                pkg.override { cudaArches = requiredArches; }
              else
                pkg;
          };
      in
      builtins.mapAttrs mkPool config.fw.hardware.gpus.pools;

    environment.systemPackages = lib.optionals (!config.fw.hardware.gpus.hasVendor.amd) [
      # nvtopPackages.nvidia cannot see AMD cards and .amd cannot see NVIDIA
      # ones, so a host with both vendors gets the one variant that sees both
      # from modules/amd.nix. Two nvtops in one environment would collide.
      pkgs.nvtopPackages.nvidia
    ];

    nixpkgs.config.nvidia.acceptLicense = true;
    hardware.nvidia-container-toolkit.enable = true;

    # Required to provide linux-firmware, which contains the gsp_ga10x.bin firmware
    # needed by the NVIDIA driver for Ampere+ GPUs to initialize properly.
    hardware.enableRedistributableFirmware = true;

    # Put GPU firmware onto filesystem rather than falling back to the version
    # embedded into kernel.
    hardware.firmware = [ config.hardware.nvidia.package.firmware ];

    # Graphics must be enabled to generate /run/opengl-driver/lib,
    # which is where nvidia-persistenced and other tools look for libraries.
    # Necessary to create /run/opengl-driver, which must be forwarded to NixOS
    # containers for using GPU (CUDA) inside them.
    hardware.graphics.enable = true;

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
            builtins.map (gpu: ''
              ${config.hardware.nvidia.package.bin}/bin/nvidia-smi -i ${gpu.uuid} -pl ${toString gpu.powerLimit} || true
            '') limits
          );
    };

    services.telegraf = lib.mkIf (config.services.telegraf.enable or false) {
      extraConfig.inputs = {
        nvidia_smi.bin_path = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
        # Workaround: Telegraf's nvidia_smi plugin does not yet emit clocks_event_reasons_counters
        # (see https://github.com/influxdata/telegraf/issues/19404). Query them directly via
        # nvidia-smi CSV output using the exact same measurement and field names as the native
        # plugin. Remove this workaround when the upstream fix is deployed in Telegraf.
        exec = [
          {
            commands = [
              "${pkgs.writeShellScript "nvidia-throttle-counters" ''
                ${config.hardware.nvidia.package.bin}/bin/nvidia-smi \
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
  };
}
