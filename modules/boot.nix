{
  pkgs,
  lib,
  options,
  config,
  rootDisks ? [ ],
  ...
}:
let
  inherit (config.boot.loader.efi) efiSysMountPoint;

  # ESPs of the extra boot disks, in bay order.
  mirrorTargets = map (index: "/boot${toString index}") (lib.range 2 (builtins.length rootDisks));

  # Copies the bootloader from the first ESP to the others.
  mirrorEfi = pkgs.writeShellScript "efi-mirror" ''
    set -eu

    if [ ! -r ${efiSysMountPoint}/EFI/BOOT/BOOTX64.EFI ] && [ ! -r ${efiSysMountPoint}/EFI/Linux ]; then
      echo "Boot sentinel file missing, refusing to mirror" >&2
      exit 66
    fi
    ${lib.concatMapStringsSep "\n" (
      target: "${pkgs.rsync}/bin/rsync -avz --delete ${efiSysMountPoint}/ ${lib.escapeShellArg target}"
    ) mirrorTargets}
  '';
in
lib.mkMerge [
  {
    boot.loader = {
      # No need to touch machine's NVRAM, we just put bootloader where it is
      # expected by default: /part(type=EF00)/EFI/BOOT/BOOTX64.EFI
      # This works very well when swapping boot disks.
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot1";
      systemd-boot = {
        enable = true;
        memtest86.enable = true;
        configurationLimit = 5;
      };
    };

    systemd.services.efi-mirror = {
      enable = builtins.length rootDisks > 1;
      script = "exec ${mirrorEfi}";
      serviceConfig = {
        Type = "oneshot";
      };
      unitConfig = {
        OnFailure = [ "notify-failed@%n.service" ];
      };
      startAt = "hourly";
      requires = [ "local-fs.target" ];
    };

    # Can't simply "systemctl start efi-mirror":
    # - it's missing during initial install
    # - it's still disabled during upgrade from 1-disk to 2-disk configuration
    boot.loader.systemd-boot.extraInstallCommands = lib.mkIf (builtins.length rootDisks > 1) ''
      ${mirrorEfi} || echo "warning: failed to mirror the ESPs, the efi-mirror timer will retry"
    '';
  }

  # Use Lanzaboote's native support for mirroring bootloader files to other ESPs
  (lib.optionalAttrs (options ? boot.lanzaboote) {
    boot.lanzaboote.extraEfiSysMountPoints = lib.mkIf (config.boot.lanzaboote.enable or false) (
      builtins.genList (i: "/boot${toString (i + 2)}") (builtins.length rootDisks - 1)
    );
  })
]
