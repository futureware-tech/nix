{ lib, options, ... }:
{
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 60d";
  }
  // lib.optionalAttrs (options.nix.gc ? dates) {
    # NixOS
    dates = lib.mkDefault "00:15";
  }
  // lib.optionalAttrs (options.nix.gc ? interval) {
    # Darwin
    interval = lib.mkDefault {
      Hour = 0;
      Minute = 15;
    };
  };
}
