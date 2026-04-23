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
  hasSystemd = options ? systemd;
in
lib.mkMerge [
  {
    nix.settings = {
      substituters = [
        "http://nix-cache.home.arpa/cache.nixos.org"
        "http://nix-cache.home.arpa/nix-community.cachix.org"
        "http://nix-cache.home.arpa/cuda-maintainers.cachix.org"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
      ];
    };

    # For fetch over SSH (repos where auth is required) or push.
    programs.ssh.knownHosts."git.home.arpa".publicKey =
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDwfA6BEClvgqiQrOU6Bm5oxqXaFZ0zkgsJ0Hi5NzT4shXTRhqHeHjnxJlcL191Sd+46oX4wTg4fp2W1f6JtMloNnbvnGSgdzDv0zGMU3zFcCiYR202+xV9iOvR6SkCmhArfRgiWD7n7umjFNYsCYgkUzZ93Ot3qaCdvx7sn7IUFCZdd5PzR11JBOpxlU/bgG3nktOn28R5mfyoimm4nKQDmKkvwy3kQZ+0iCRjUc4g1xZaizhKeFEns+GjNfUgWfk27yQ6H02oFfBPf9v47UxJ0/dUtCswoVrU60zPqVfWE9qoo/Zu2wbMVnu+CK7MW2XyctzHsjYp3A+pHeB1rCtUi6jugist4y6fdn4vu5HDW4eXFk+6G94zJQF9ueojzv9488pt5OKkO6+VPxpNMxikduTvMOPk1FxyxJL8ZLND4WF6CS3rejDUB8hG2eqEdIZI55VX4Zp7yHOhmMpjz8R1Lx2uRx/kcqYb6pomvIWxKsVEIQpueyR/icsliPw3Kv9fHKrFW1w/jYbWnUA2SnYBziwwD2eA7jgsekQoDPtXwE37YkhZ21xBQqXoLYIb9fSHKo95jyOKHUAWI/AT4X1aoAEzoqRCrb3ENz85F81yhpNHtOs67MrPUl2XAxjXfCgwOhgu4bJSizHl3/8GAngDNwSfCoWMjR+HolZZ1Uezmw=="; # pragma: allowlist secret
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
