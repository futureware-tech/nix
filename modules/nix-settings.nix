_: {
  nix.settings = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
    ];

    auto-optimise-store = true;

    trusted-users = [ "@wheel" ];

    # RPi builds can be slow due to compiling via binfmt.
    download-buffer-size = 1 * 1024 * 1024 * 1024;
  };
}
