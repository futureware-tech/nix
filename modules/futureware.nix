# This module is supposed to be used on internal FutureWare servers.

{ lib, options, ... }:

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

  (lib.mkIf hasGitOption {
    programs.git.enable = true;
    programs.git.config = gitConfig;
  })

  (lib.mkIf (!hasGitOption) {
    # nix-darwin
    environment.etc."gitconfig".text = lib.generators.toGitINI gitConfig;
  })
]
