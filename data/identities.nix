let
  artemKey = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxRBsFGa8OFbviYDGSAKLgfm/K2XUxvCo+31FW37yab";
  };
in
rec {
  # API
  getAccessKeys =
    { user }:
    let
      u = users.${user};
    in
    map (
      name:
      let
        k = u.access.${name};
      in
      "${k.publicKey} ${name}"
    ) (builtins.attrNames u.access);

  getSigningEntries =
    {
      user ? null,
    }:
    let
      getEntries =
        u:
        map (
          name:
          let
            k = u.sign.${name};
          in
          "${u.email} namespaces=\"${k.namespace}\" ${k.publicKey} ${name}"
        ) (builtins.attrNames u.sign);
    in
    if user == null then
      builtins.concatLists (map getEntries (builtins.attrValues users))
    else
      getEntries users.${user};

  # Data
  users = {
    artem = {
      email = "dot.doom@gmail.com";
      access = {
        "ssh@mars".publicKey =
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJg7zQ4H0LQeQcILZBwCzQ+MYKtCgKm7HPe9oFeoyprKZXAvpm+HDHtaYdU39JF9f+nvRztzXuMhgETAQMAQCkc=";
        yubikey-office.publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPAtIXXHm58julnr7S0xzBTM1jN5JkKxOL4JpuWDOa2jAAAABHNzaDo=";
        yubikey-keychain.publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHY1xx0huqV6Mcc2WngYDabITeNUbGamJ8//206MxxVTAAAABHNzaDo=";
        yubikey-safe.publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHzY2eOz+JdaKOpIgZbF5FsZzQy0l8vPJjAQdTpBFGsoAAAABHNzaDo=";
        artem = artemKey;
      };

      sign = {
        # Access keys as signers
        artem = artemKey // {
          namespace = "git";
        };

        # Sign-only keys
        "sign@mars" = {
          publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNwSX/Ib6kNzgRKqWfcb3HsAQQo++Gt9KeXSvP6NDk6YQPjDsi+//IiBovgLjQ34El+x8l8y3aYhfIGlCyX7aOM=";
          namespace = "git";
        };
        yubikey-office = {
          publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHqC278Y4NCvNh4qiGtfpK5+CNQv+tTDseP67HLFX6u3AAAAEXNzaDpnaXQtc2lnbmF0dXJl";
          namespace = "git";
          serial = "36027052";
        };
        yubikey-keychain = {
          publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPBpgGDNkJHMtpZQ+1CcWdZRDUEXdjcZsxH9M9ebexb6AAAAEXNzaDpnaXQtc2lnbmF0dXJl";
          namespace = "git";
          serial = "20723090";
        };
        yubikey-safe = {
          publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOd/DCO4lo8PH9EjKMtgGBGoc6SevLvTdWVlNbjrc6NsAAAAEXNzaDpnaXQtc2lnbmF0dXJl";
          namespace = "git";
        };
      };
    };
  };
}
