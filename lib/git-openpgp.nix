# A read-only GnuPG keyring from armored public keys, plus the `gpg` wrapper
# git consults it through. The store quirks each worked around below, all of
# which gpg errors out on if taken naively:
#
# - Ultimate ownertrust is baked in, because `merge --verify-signatures`
#   requires at least marginal trust and there is no web of trust to build
#   instead. gpg validates the trustdb lazily, on first verification, and
#   that write fails fatally against the read-only store, so validation is
#   forced at build time with `--update-trustdb`.
# - gpg drops agent sockets into its homedir, which the store cannot hold,
#   so the keyring is built in a temp dir and only pubring and trustdb are
#   copied out.
# - gpg rejects a homedir it does not own, and store paths are root-owned,
#   hence --no-permission-warning in the wrapper: it only ever points at its
#   own store path, never a user homedir.
{
  pkgs,
  lib,
  keys,
  name ? "git-openpgp",
}:
let
  keysFile = pkgs.writeText "${name}-keys" (lib.concatStringsSep "\n" (lib.unique keys));

  keyring =
    pkgs.runCommand "${name}-keyring"
      {
        nativeBuildInputs = [ pkgs.gnupg ];
      }
      ''
        export GNUPGHOME=$(mktemp -d)
        chmod 700 "$GNUPGHOME"
        mkdir $out
        # Trusting no OpenPGP signer is a valid outcome; gpg --import chokes
        # on the empty file.
        if [ -s ${keysFile} ]; then
          gpg --batch --quiet --import ${keysFile}
          {
            for fpr in $(gpg --with-colons --list-keys \
              | awk -F: '$1 == "pub" { p = 1; next } p && $1 == "fpr" { print $10 ":6:"; p = 0 }'); do
              printf '%s\n' "$fpr"
            done
          } | gpg --batch --quiet --import-ownertrust
          gpg --batch --quiet --update-trustdb
          cp "$GNUPGHOME/pubring.kbx" "$GNUPGHOME/trustdb.gpg" $out/
        else
          touch $out/pubring.kbx $out/trustdb.gpg
        fi
      '';
in
{
  inherit keyring;
  gpg = pkgs.writeShellScriptBin "${name}-gpg" ''
    exec ${pkgs.gnupg}/bin/gpg --homedir ${keyring} --no-permission-warning "$@"
  '';
}
