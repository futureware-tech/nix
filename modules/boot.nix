{
  pkgs,
  lib,
  options,
  config,
  rootDisks ? [ ],
  ...
}:
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

    boot.initrd.systemd.enable = true;

    systemd.services.efi-mirror = {
      enable = builtins.length rootDisks > 1;
      script = ''
        set -eu

        if [ -r /boot1/EFI/BOOT/BOOTX64.EFI ] || [ -r /boot1/EFI/Linux ]; then
          for target in /boot{2..${toString (builtins.length rootDisks)}}; do
            ${pkgs.rsync}/bin/rsync -avz --delete /boot1/ "$target"
          done
        else
          echo "Boot sentinel file missing, refusing to mirror" >&2
          exit 66
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
      };
      unitConfig = {
        OnFailure = [ "notify-failed@%n.service" ];
      };
      startAt = "hourly";
      requires = [ "local-fs.target" ];
    };

    boot.loader.systemd-boot.extraInstallCommands = lib.mkIf (
      builtins.length rootDisks > 1
    ) "${pkgs.systemd}/bin/systemctl start efi-mirror.service";
  }

  # Use Lanzaboote's native support for mirroring bootloader files to other ESPs
  (lib.optionalAttrs (options ? boot.lanzaboote) {
    boot.lanzaboote.extraEfiSysMountPoints = lib.mkIf (config.boot.lanzaboote.enable or false) (
      builtins.genList (i: "/boot${toString (i + 2)}") (builtins.length rootDisks - 1)
    );
  })
]
