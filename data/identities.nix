rec {
  # API
  getAccessKeys = user: map (k: k.key) (builtins.attrValues users.${user}.access);
  getSigningEntries = user: map (k: k.entry) (builtins.attrValues users.${user}.sign);

  # Data
  users = {
    artem = {
      access = {
        ssh-mars = {
          key = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJg7zQ4H0LQeQcILZBwCzQ+MYKtCgKm7HPe9oFeoyprKZXAvpm+HDHtaYdU39JF9f+nvRztzXuMhgETAQMAQCkc= ssh@mars";
        };
        yubikey-office = {
          key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPAtIXXHm58julnr7S0xzBTM1jN5JkKxOL4JpuWDOa2jAAAABHNzaDo= yubikey-office";
        };
        yubikey-keychain = {
          key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHY1xx0huqV6Mcc2WngYDabITeNUbGamJ8//206MxxVTAAAABHNzaDo= yubikey-keychain";
        };
        yubikey-safe = {
          key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHzY2eOz+JdaKOpIgZbF5FsZzQy0l8vPJjAQdTpBFGsoAAAABHNzaDo= yubikey-safe";
        };
        artem = {
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxRBsFGa8OFbviYDGSAKLgfm/K2XUxvCo+31FW37yab artem";
        };
      };

      sign = {
        # Access keys as signers
        artem = {
          entry = "dot.doom@gmail.com namespaces=\"git\" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxRBsFGa8OFbviYDGSAKLgfm/K2XUxvCo+31FW37yab artem";
        };

        # Sign-only keys
        sign-mars = {
          entry = "dot.doom@gmail.com namespaces=\"git\" ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNwSX/Ib6kNzgRKqWfcb3HsAQQo++Gt9KeXSvP6NDk6YQPjDsi+//IiBovgLjQ34El+x8l8y3aYhfIGlCyX7aOM= sign@mars";
        };
        yubikey-office = {
          entry = "dot.doom@gmail.com namespaces=\"git\" sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHqC278Y4NCvNh4qiGtfpK5+CNQv+tTDseP67HLFX6u3AAAAEXNzaDpnaXQtc2lnbmF0dXJl yubikey-keychain";
          serial = "36027052";
        };
        yubikey-keychain = {
          entry = "dot.doom@gmail.com namespaces=\"git\" sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPBpgGDNkJHMtpZQ+1CcWdZRDUEXdjcZsxH9M9ebexb6AAAAEXNzaDpnaXQtc2lnbmF0dXJl yubikey-keychain";
          serial = "20723090";
        };
        yubikey-safe = {
          entry = "dot.doom@gmail.com namespaces=\"git\" sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOd/DCO4lo8PH9EjKMtgGBGoc6SevLvTdWVlNbjrc6NsAAAAEXNzaDpnaXQtc2lnbmF0dXJl yubikey-safe";
        };
      };
    };
  };
}
