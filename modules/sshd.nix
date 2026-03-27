_: {
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
    hostKeys = [
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
