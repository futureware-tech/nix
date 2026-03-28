# This module is supposed to be used on internal FutureWare servers.

{
  lib,
  options,
  pkgs,
  ...
}:

let
  gitConfig = {
    url."https://git.sheremet.ch/futureware-tech/nix.git".insteadOf =
      "https://github.com/futureware-tech/nix.git";
    url."https://git.sheremet.ch/artem/dotfiles.git".insteadOf =
      "https://github.com/dotdoom/dotfiles.git";
    url."https://git.sheremet.ch/home/esphome.git".insteadOf = "https://github.com/dotdoom/esphome.git";
  };
  hasGitOption = options ? programs.git;
in
lib.mkMerge [
  {
    nix.settings = {
      substituters = [
        "http://nix-cache.home.arpa"
        # nix-community cachix server
        # TODO: this, but through our cache -- "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        # "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  }

  (lib.optionalAttrs hasGitOption {
    programs.git.enable = true;
    programs.git.config = gitConfig;
  })

  (lib.optionalAttrs (!hasGitOption) {
    # This typically means nix-darwin, which doesn't have "programs.git".
    #
    # /etc/gitconfig is completely ignored by git built by nix-darwin, as it
    # has its own gitconfig instead.
    #
    # Overlaying git package to add our stuff into that gitconfig causes
    # half of the world to rebuild.
    #
    # We point at /etc/gitconfig using system variables for login shells
    # and nix daemon, but other daemons and GUI applications will ignore these
    # settings.
    environment.etc."gitconfig".text = lib.generators.toGitINI (
      gitConfig // { include.path = "${pkgs.git}/etc/gitconfig"; }
    );
    nix.envVars.GIT_CONFIG_SYSTEM = "/etc/gitconfig";
    environment.variables.GIT_CONFIG_SYSTEM = "/etc/gitconfig";
  })
]
