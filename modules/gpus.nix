# Deliberately not a flake output: a host gets these options by importing a
# vendor module.
{
  pkgs,
  lib,
  config,
  ...
}:
let
  vendors = [
    "nvidia"
    "amd"
  ];

  gpuDevices = builtins.attrValues config.fw.hardware.gpus.devices;

  # One card. Reused as the value type of both `devices` and the resolved
  # `devices` of each pool, so a pool hands out the same typed submodule a host
  # declared rather than untyped attrs.
  deviceType = lib.types.submodule {
    options = {
      vendor = lib.mkOption {
        type = lib.types.enum vendors;
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
  };

  nvtop =
    let
      present = builtins.filter (vendor: config.fw.hardware.gpus.hasVendor.${vendor}) vendors;
    in
    if builtins.length present == 1 then
      pkgs.nvtopPackages.${lib.head present}
    else
      pkgs.nvtopPackages.full;

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
    type = lib.types.attrsOf deviceType;
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
            type = lib.types.listOf deviceType;
            description = "Device submodules in this pool";
          };
          uuids = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of UUIDs of the GPUs in this pool";
          };
          environment = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            description = ''
              Environment variables for this pool (CUDA_VISIBLE_DEVICES,
              NVIDIA_VISIBLE_DEVICES). Empty for a pool with no NVIDIA cards:
              both variables are meaningless to a ROCm container.
            '';
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
    default = lib.genAttrs vendors (_: false);
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

    fw.hardware.gpus.hasVendor = lib.genAttrs vendors (
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
            gpus = map (name: config.fw.hardware.gpus.devices.${name}) deviceNames;

            uuids = builtins.sort builtins.lessThan (map (gpu: gpu.uuid) gpus);

            # CUDA_VISIBLE_DEVICES and NVIDIA_VISIBLE_DEVICES are NVIDIA's, so a
            # pool of AMD cards gets neither, and a pool that somehow mixes
            # vendors only ever sees the NVIDIA cards in them.
            nvidiaUuids = builtins.sort builtins.lessThan (
              map (gpu: gpu.uuid) (builtins.filter (gpu: gpu.vendor == "nvidia") gpus)
            );

            # Only GPUs with compute=true contribute their cudaCapability to build-time arches.
            computeGpus = builtins.filter (gpu: gpu.compute) gpus;
            caps = map (gpu: gpu.cudaCapability) computeGpus;
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
            environment = lib.optionalAttrs (nvidiaUuids != [ ]) {
              CUDA_VISIBLE_DEVICES = builtins.concatStringsSep "," nvidiaUuids;
              NVIDIA_VISIBLE_DEVICES = builtins.concatStringsSep "," nvidiaUuids;
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

    environment.systemPackages = [ nvtop ];

    # Graphics must be enabled to generate /run/opengl-driver/lib, which is
    # where vendor driver libraries are looked up (nvidia-persistenced on an
    # NVIDIA host, GL/EGL users of amdgpu on an AMD one). It is also what
    # containers consuming a GPU pool need mounted in.
    hardware.graphics.enable = true;

    # GPU firmware ships in linux-firmware: the gsp_ga10x.bin blob the NVIDIA
    # driver needs to initialise Ampere+ cards, and the amdgpu firmware.
    hardware.enableRedistributableFirmware = true;
  };
}
