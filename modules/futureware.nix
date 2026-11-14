# This module is supposed to be used on internal FutureWare servers.

{
  lib,
  options,
  pkgs,
  ...
}:

let
  identities = import ../data/identities.nix;
  gitConfig = {
    url."https://git.sheremet.ch/futureware-tech/nix.git".insteadOf =
      "https://github.com/futureware-tech/nix.git";
    url."https://git.sheremet.ch/artem/dotfiles.git".insteadOf =
      "https://github.com/dotdoom/dotfiles.git";
    url."https://git.sheremet.ch/home/esphome.git".insteadOf = "https://github.com/dotdoom/esphome.git";
  };
  hasGitOption = options ? programs.git;
  hasSystemd = options ? systemd;
in
lib.mkMerge [
  {
    nix.settings = {
      substituters = [
        "http://nix-cache.home.arpa/attic/public"
        "http://nix-cache.home.arpa/cache.nixos.org"
        "http://nix-cache.home.arpa/nix-community.cachix.org"
        "http://nix-cache.home.arpa/cache.nixos-cuda.org"
      ];
      trusted-public-keys = [
        "public:F/Ufy/WmDK+exxFlNsRf+p3Ir2b+Vj+N+zfGDFrRXQ8="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
      ];

      # Limit impact in case any of these are unavailable.
      connect-timeout = lib.mkDefault 5;
      fallback = lib.mkDefault true;
    };

    # For fetch over SSH (repos where auth is required) or push.
    programs.ssh.knownHosts = identities.getKnownHosts;
  }

  (lib.optionalAttrs hasSystemd {
    # Most LAN servers only have IPv4 DNS names.
    systemd.network.wait-online.extraArgs = [ "--ipv4" ];
  })

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
