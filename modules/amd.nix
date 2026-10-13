{
  pkgs,
  lib,
  config,
  ...
}:
{
  # AMD side of fw.hardware.gpus. Whether a host needs it is not a separate
  # switch: it follows from the cards listed in fw.hardware.gpus.devices, so a
  # host cannot claim an AMD card and forget to install the tooling for it.
  #
  # Depends on modules/nvidia.nix, which declares fw.hardware.gpus.devices, but
  # reads the vendor list defensively so it can be imported on its own.
  config = lib.mkIf (config.fw.hardware.gpus.hasVendor.amd or false) {
    environment.systemPackages = with pkgs.rocmPackages; [
      # rocm-smi reads the same sysfs the amdgpu driver publishes, so it works
      # without the full ROCm runtime.
      rocm-smi
      rocminfo

      # nvtopPackages.nvidia cannot see AMD cards and .amd cannot see NVIDIA
      # ones, so a host with both vendors gets the one variant that sees both.
      # Two nvtops in one environment would collide, so modules/nvidia.nix
      # withholds its own copy whenever an AMD card is present.
      pkgs.nvtopPackages.full
    ];
  };
}
