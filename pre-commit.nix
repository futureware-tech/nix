{
  # Only a module function gets `pkgs`, and the commit-message hook needs it to
  # name its own binary and config by absolute store path.
  imports = [
    (
      { pkgs, ... }:
      {
        # Commit messages must be canonical: a Conventional Commits subject plus
        # an optional body. The rules live in ./.gitlint, passed explicitly so
        # every repo importing these hooks gets the same policy instead of
        # gitlint's stock defaults (which demand a body). A repo wanting its own
        # rules overrides hooks.gitlint.entry.
        hooks.gitlint.entry = "${pkgs.gitlint}/bin/gitlint -C ${./.gitlint} --staged --msg-filename";
      }
    )
  ];

  hooks = {
    gitlint.enable = true;

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
    prettier.enable = true;
    clang-format = {
      enable = true;
      # git-hooks.nix copies upstream's types_or, which includes json and
      # javascript. clang-format reformats those too (expanding short arrays),
      # which fights prettier: each hook rewrites what the other just wrote
      # and neither converges. Restrict it to the languages it is for.
      types_or = [
        "c"
        "c++"
        "cuda"
        "objective-c"
      ];
    };
    black.enable = true;

    # Nix
    flake-checker.enable = true;
    nixfmt.enable = true;
    deadnix.enable = true;
    nil.enable = true;
    nixf-diagnose.enable = true;
    statix = {
      enable = true;
      settings.config = "${./assets/statix.toml}";
    }; # Use: statix fix
  };
}
