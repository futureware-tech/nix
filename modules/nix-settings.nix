{
  lib,
  pkgs,
  ...
}:
{
  nix.settings = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
    ];

    trusted-users = [ "@wheel" ];

    # RPi builds can be slow due to compiling via binfmt.
    download-buffer-size = 1 * 1024 * 1024 * 1024;
  };

  nix.optimise = {
    # Instead of nix.settings.auto-optimise-store, which adds overhead to each
    # build.
    automatic = true;
  }
  // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
    dates = lib.mkDefault "00:45";
  }
  // lib.optionalAttrs pkgs.stdenv.isDarwin {
    interval = lib.mkDefault {
      Hour = 0;
      Minute = 45;
    };
  };
}
