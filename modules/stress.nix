{
  pkgs,
  lib,
  config,
  ...
}:
let
  hasVendor = vendor: config.fw.hardware.gpus.hasVendor.${vendor} or false;

  # CUDA-enabled subset of packages (do not enable for everything to avoid
  # global recompile).
  cudaPkgs = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = config.fw.hardware.gpus.allCudaCapabilities or [ ];
    };
  };
in
{
  options.fw.hardware.stress.enable = lib.mkEnableOption ''
    tools for deliberately loading the machine to check its cooling, power
    delivery and stability under full utilisation
  '';

  config = lib.mkIf config.fw.hardware.stress.enable {
    environment.systemPackages = [
      pkgs.fio
      pkgs.stress
    ]
    ++ lib.optionals (hasVendor "nvidia") [
      # To run a GPU stress test:
      # gpu_burn -m 99% 900
      cudaPkgs.gpu-burn
    ]
    ++ lib.optionals (hasVendor "amd") [
      # nixpkgs has no gpu_burn for AMD: the package is CUDA-only and marked
      # broken without CUDA support. rocblas-bench does the same kind of
      # sustained SGEMM work and reports GFLOP/s. On the R9700 (gfx1201):
      #   rocblas-bench -f sgemm -m 8192 -n 8192 -k 8192 -i 1000 -v 1
      #   watch -n1 rocm-smi --showpower --showtemp --showclocks
      pkgs.rocmPackages.rocblas.benchmark
    ];
  };
}
