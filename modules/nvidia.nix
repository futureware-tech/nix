{
  pkgs,
  lib,
  config,
  ...
}:
let
  # CUDA-enabled subset of packages (do not enable for everything to avoid
  # global recompile).
  cudaPkgs = import pkgs.path {
    inherit (pkgs) system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = config.fw.hardware.gpus.allCudaCapabilities;
    };
  };
in
{
  options.fw.hardware.gpus.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.fw.hardware.gpus.devices != { };
    description = "Enable NVIDIA GPU drivers and configuration";
  };

  options.fw.hardware.gpus.devices = lib.mkOption {
    description = "Attribute set of GPUs installed on this host";
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          uuid = lib.mkOption {
            type = lib.types.str;
            description = "UUID from nvidia-smi";
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

  config = lib.mkIf config.fw.hardware.gpus.enable {
    fw.hardware.gpus.allCudaCapabilities = lib.unique (
      builtins.sort builtins.lessThan (
        builtins.filter (x: x != null) (
          builtins.map (gpu: gpu.cudaCapability) (builtins.attrValues config.fw.hardware.gpus.devices)
        )
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

    environment.systemPackages = with pkgs; [
      nvtopPackages.nvidia

      # TODO: move these 3 to stresstest.nix:

      fio

      # To run a CPU stress test for the AMD Ryzen 7 7700X (8-Core/16-Thread):
      # stress --cpu 16 --vm 8 --io 16 --timeout 900
      stress

      # To run a GPU stress test:
      # gpu_burn -m 99% 900
      cudaPkgs.gpu-burn
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
          limits = builtins.filter (gpu: gpu.powerLimit != null) (
            builtins.attrValues config.fw.hardware.gpus.devices
          );
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
      extraConfig.inputs.nvidia_smi.bin_path = "${config.hardware.nvidia.package.bin}/bin/nvidia-smi";
    };
  };
}
