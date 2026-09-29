{ lib, ... }: {
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;

    # mkDefault (p1000) overrides nixpkgs-provided mkOptionDefault (p1500), but
    # allows further overrides by hosts with unencrypted impermanence using
    # standard setter (p100).
    hostKeys = lib.mkDefault [
      # Generate a key if it's missing, which is normal at first boot, but can
      # also be a TPM failure for PCs with a TPM.
      # Do not generate an RSA key.
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };
}
