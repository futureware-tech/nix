{
  config,
  pkgs,
  lib,
  ...
}:
let
  age-tpm = pkgs.writeShellApplication {
    name = "age-tpm";
    runtimeInputs = with pkgs; [
      age
      age-plugin-tpm
    ];
    # The point is for "age" to have "age-plugin-tpm" in PATH.
    text = "exec age \"$@\"";
  };

  # Determine which classes of secrets exist so we only add activation dependencies if
  # sops-nix is actually going to generate the respective activation scripts.
  hasRegularSecrets = lib.any (s: !s.neededForUsers) (lib.attrValues config.sops.secrets);
  hasUserSecrets = lib.any (s: s.neededForUsers) (lib.attrValues config.sops.secrets);
in
{
  options.fw.tpm = {
    hostPath = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = null;
      description = "Path to the host directory containing tpm.id and secrets/ssh_host_ed25519_key.age";
    };
  };

  config = {
    boot.initrd.kernelModules = [
      "tpm_crb" # NUC built-int TPM
      "tpm_tis" # SuperMicro TPM
    ];

    # Q: Why agenix/sops instead of systemd-creds aka LoadCredential?
    # A: To read and edit credentials on developer VM, even if target-host is
    #    unavailable, or was reinstalled.
    # Q: Why both agenix and sops-nix?
    # A: Decrypting 20 secrets using TPM is too slow, so we use two-stage setup.
    #    We put master key (SSH host key) into agenix which uses TPM, then
    #    decrypt all other secrets using sops and master key.
    age = lib.mkIf (config.fw.tpm.hostPath != null) {
      ageBin = "${age-tpm}/bin/age-tpm";

      # Generate .id file on target-host using:
      #   nix run nixpkgs#age-plugin-tpm -- --generate -o $(hostname).id
      # then copy locally and add to repo. The contained blob is useless without
      # TPM itself, and can therefore be checked into a Git repo.
      #
      # Interpolation forces file to be copied to target host.
      identityPaths = [ "${config.fw.tpm.hostPath + "/tpm.id"}" ];

      secrets.ssh_host_ed25519_key = {
        file = config.fw.tpm.hostPath + /secrets/ssh_host_ed25519_key.age;
        path = "/etc/ssh/ssh_host_ed25519_key";
      };
    };

    # sops needs SSH key, which is decrypted by "agenixInstall". We can't depend
    # on "agenix" because that happens after users have been set up (to chown).
    system.activationScripts.setupSecrets = lib.mkIf hasRegularSecrets {
      deps = lib.mkAfter [ "agenixInstall" ];
    };
    system.activationScripts.setupSecretsForUsers = lib.mkIf hasUserSecrets {
      deps = lib.mkAfter [ "agenixInstall" ];
    };

    sops.secrets.root-password = lib.mkIf (config.fw.tpm.hostPath != null) {
      # Having a TPM allows us to share root user password. It is useful for
      # recovering from systemd "emergency" mode.
      sopsFile = (dirOf config.fw.tpm.hostPath) + /common/secrets/root-password.bin;
      format = "binary";
      neededForUsers = true;
    };
    users.users.root.hashedPasswordFile = lib.mkIf (
      config.fw.tpm.hostPath != null
    ) config.sops.secrets.root-password.path;
  };
}
