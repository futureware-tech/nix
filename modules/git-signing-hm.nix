# Home-manager counterpart of modules/git-signing.nix: importing it activates
# it, there are no options. Interactive `git log --show-signature` then
# verifies agent commits too (without it they read "Can't check signature: No
# public key"). Settings are mkDefault, so a consumer's own git config wins.
#
# Caveat: `gpg.program` is only consulted for OpenPGP signatures, so ssh
# signers (a YubiKey through ssh-agent, the usual case) are untouched — but a
# user who signs with gpg.format=openpgp needs their real keyring and must
# not import this module.
{
  options,
  lib,
  pkgs,
  identities ? null,
  ...
}:
let
  inherit (lib) mkDefault;

  hasGitOption = options ? programs.git;

  allowedSignersFile = pkgs.writeText "git-allowed-signers" (
    lib.concatStringsSep "\n" (if identities == null then [ ] else identities.getSigningEntries { })
  );

  openpgp = import ../lib/git-openpgp.nix {
    inherit pkgs lib;
    keys = if identities == null then [ ] else identities.getOpenpgpKeys { };
    name = "git-openpgp-user";
  };
in
{
  config = lib.mkIf hasGitOption {
    programs.git = {
      enable = true;
      settings = {
        gpg.program = mkDefault "${openpgp.gpg}/bin/git-openpgp-user-gpg";
        gpg.ssh.allowedSignersFile = mkDefault allowedSignersFile;
      };
    };
  };
}
