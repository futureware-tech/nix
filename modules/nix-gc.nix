{
  lib,
  pkgs,
  ...
}:
{
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 60d";
  }
  // lib.optionalAttrs (!pkgs.stdenv.hostPlatform.isDarwin) {
    dates = lib.mkDefault "00:15";
  }
  // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
    interval = lib.mkDefault {
      Hour = 0;
      Minute = 15;
    };
  };
}
