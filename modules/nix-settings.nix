_: {
  nix.settings = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
    ];

    trusted-users = [ "@wheel" ];

    # RPi builds can be slow due to compiling via binfmt.
    download-buffer-size = 1 * 1024 * 1024 * 1024;
  };

  # Instead of nix.settings.auto-optimise-store, which adds overhead to each
  # build.
  nix.optimise.automatic = true;
}
