{
  pkgs,
  lib,
  config,
  ...
}:
{
  imports = [ ./gpus.nix ];

  # AMD side of fw.hardware.gpus. Whether a host needs it is not a separate
  # switch: it follows from the vendors of the cards listed in
  # fw.hardware.gpus.devices, so a host cannot claim an AMD card and forget to
  # install the tooling for it. The shared option declarations, pool resolution
  # and vendor-neutral tooling live in modules/gpus.nix.
  #
  # hasVendor is only ever set true while `enable` holds, so the `enable` test is
  # redundant on its own; keep both so the gate names the option it mirrors.
  config = lib.mkIf (config.fw.hardware.gpus.enable && config.fw.hardware.gpus.hasVendor.amd) {
    environment.systemPackages = with pkgs.rocmPackages; [
      # rocm-smi reads the same sysfs the amdgpu driver publishes, so it works
      # without the full ROCm runtime.
      rocm-smi
      rocminfo
    ];
  };
}
