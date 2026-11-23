# Per-directory, declarative git commit-signature verification.
#
# Each declared directory gets an `includeIf` in the system gitconfig pointing
# at generated trust material, so a git command running there verifies
# signatures even as a user without a home; sync services need no git
# plumbing of their own.
#
# Trust is per directory on purpose: a dir trusts only the identities its
# repository actually needs, and `users` defaults to every identities user.
#
# Usage:
#
#     fw.git.signing."/etc/nixos" = { };
#     fw.git.signing."/srv/repo".users = [ "artem" ];
{
  config,
  options,
  lib,
  pkgs,
  identities ? null,
  ...
}:
let
  inherit (lib)
    attrNames
    concatMapStringsSep
    mkIf
    mkOption
    types
    ;

  cfg = config.fw.git.signing;

  # nix-darwin has no programs.git; guard so the module stays cross-platform.
  hasGitOption = options ? programs.git;

  allUsers = if identities == null then [ ] else attrNames identities.users;

  signerEntriesFor =
    users: lib.unique (builtins.concatMap (u: identities.getSigningEntries { user = u; }) users);

  openpgpKeysFor =
    users: lib.unique (builtins.concatMap (u: identities.getOpenpgpKeys { user = u; }) users);

  # One include file per directory, since includeIf only fires for the
  # directory it is scoped to.
  signingInclude =
    dir: trust:
    let
      slug = lib.concatStringsSep "-" (lib.filter (x: x != "") (lib.splitString "/" dir));
      allowedSignersFile = pkgs.writeText "git-allowed-signers-${slug}" (
        concatMapStringsSep "\n" (entry: entry) (signerEntriesFor trust.users)
      );
      openpgp = import ../lib/git-openpgp.nix {
        inherit pkgs lib;
        keys = openpgpKeysFor trust.users;
        name = "git-openpgp-${slug}";
      };
    in
    pkgs.writeText "git-signing-config-${slug}" ''
      [gpg]
        format = ssh
        program = ${openpgp.gpg}/bin/git-openpgp-${slug}-gpg
      [gpg "ssh"]
        allowedSignersFile = ${allowedSignersFile}
      [safe]
        directory = ${dir}
    '';

  dirModule = types.submodule {
    options.users = mkOption {
      type = types.listOf types.str;
      default = allUsers;
      example = [ "artem" ];
      description = ''
        Identities users whose ssh and OpenPGP signing keys are trusted for
        this directory. Defaults to every identities user.
      '';
    };
  };
in
{
  options.fw.git.signing = mkOption {
    type = types.attrsOf dirModule;
    default = { };
    example = lib.literalExpression ''
      fw.git.signing."/etc/nixos".users = [ "artem" ];
    '';
    description = ''
      Per-directory commit-signature trust. Each attribute name is an
      absolute repository directory (or its parent); its entries become an
      `includeIf` block in the system git config, consulted by any git
      command running inside that directory.
    '';
  };

  config = mkIf (cfg != { } && hasGitOption) {
    programs.git.enable = true;
    # Nested section.subsection shape: newer nixpkgs types programs.git.config
    # as sections of key/value pairs, so a flat "…path" key no longer fits.
    programs.git.config = lib.listToAttrs (
      lib.mapAttrsToList (dir: trust: {
        name = "includeIf \"gitdir:${dir}/\"";
        value = {
          path = signingInclude dir trust;
        };
      }) cfg
    );
  };
}
