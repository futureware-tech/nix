{
  hooks = {
    check-added-large-files.enable = true;
    check-case-conflicts.enable = true;
    check-executables-have-shebangs.enable = true;
    check-merge-conflicts.enable = true;
    check-symlinks.enable = true;
    check-vcs-permalinks.enable = true;
    check-yaml.enable = true;
    end-of-file-fixer.enable = true;
    trim-trailing-whitespace.enable = true;
    ripsecrets.enable = true;

    # Nix
    flake-checker.enable = true;
    nixfmt.enable = true;
    deadnix.enable = true;
    nil.enable = true;
    statix = {
      enable = true;
      settings.config = "${./assets/statix.toml}";
    }; # Use: statix fix
  };
}
