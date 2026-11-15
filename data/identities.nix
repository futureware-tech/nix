let
  artemKey = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBxRBsFGa8OFbviYDGSAKLgfm/K2XUxvCo+31FW37yab";
  };
  katarinaKey = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEsEXAcf8dBBfNJJzALsa/+hmQo+ysp6yO3VgQ8ynxkT";
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

  getKnownHosts = builtins.listToAttrs (
    builtins.concatMap (
      host:
      map (keyName: {
        name = "${host}-${keyName}";
        value = {
          hostNames = [ host ];
          publicKey = hostKeys.${host}.${keyName}.publicKey;
        };
      }) (builtins.attrNames hostKeys.${host})
    ) (builtins.attrNames hostKeys)
  );

  # Data
  users = {
    artem = {
      email = "dot.doom@gmail.com";
      access = {
        "ssh@mars-old".publicKey =
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBJg7zQ4H0LQeQcILZBwCzQ+MYKtCgKm7HPe9oFeoyprKZXAvpm+HDHtaYdU39JF9f+nvRztzXuMhgETAQMAQCkc=";
        "ssh@mars".publicKey =
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNTbod2QJoIbMhlKWLSVq0MY/xfsnUVOBPQBQjo/2puaRt6z5SseEOgZIWKTsn7HkAS04d4iPUWOC7KM0ZmmH0c=";
        yubikey-office.publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIPAtIXXHm58julnr7S0xzBTM1jN5JkKxOL4JpuWDOa2jAAAABHNzaDo=";
        yubikey-keychain.publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHY1xx0huqV6Mcc2WngYDabITeNUbGamJ8//206MxxVTAAAABHNzaDo=";
        yubikey-safe.publicKey = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHzY2eOz+JdaKOpIgZbF5FsZzQy0l8vPJjAQdTpBFGsoAAAABHNzaDo=";
        iphone.publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBBntKrd19fN3MO9oQ9Qk5G6MHiL7O49iRWlVi7T2grgFp4Zg7EFbuNm4sehEwaiDAZmpdTN4IMOZAFm4NKq3sqY=";
        artem = artemKey;
      };

      sign = {
        # Access keys as signers
        artem = artemKey // {
          namespace = "git";
        };

        # Sign-only keys
        "sign@mars" = {
          publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBCUfJs2YefOn8CG1NCLS07a44NupFSNXs2aTLB/fopnXFKpcJzSzfyO8AG67gDta7yNYzWSZ18JXM7A40AevdfM=";
          namespace = "git";
        };
        "sign@mars-old" = {
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
    katarina = {
      email = "kate.romanowskaya@gmail.com";
      access = {
        "ssh@jupiter-old".publicKey =
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBHQZQsriIA5bNwKc3Ini4KdYcndIPnjqQd2QbnqboN9xH/A15Uqz9RmBCXfGHwMBbwA6X0vohJXio5LVm7sY10s=";
        "ssh@jupiter".publicKey =
          "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKQQVLiWmEuJoV1MVKv2815vEEGZufpXTO6xw+jwavk/UkSCe+XT565Fxd11TQ++KAYVRAh/o5OLuwrPA3qGCwY=";
        katarina = katarinaKey;
      };

      sign = {
        # Access keys as signers
        katarina = katarinaKey // {
          namespace = "git";
        };

        # Sign-only keys
        "sign@jupiter-old" = {
          publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAkUBxj2VoXYEDOcg47e4xqWk2u7Qv6vrEO1/B7E0mbtLYZ4BAGj+BuFiLGeFySbO3KP5uA93zV5UUMxOArwkn8=";
          namespace = "git";
        };
        "sign@jupiter" = {
          publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBAZVA2YNOaYF2snI0OYYWcs5YVwh79Oj5i7D83lUpBQ/U6iljtv1z/lZNgpQXNH1YGklqKpZK1FGmZBZFEyiux4=";
          namespace = "git";
        };
      };
    };
    katarina-agent = {
      email = "katarina-agent@sheremet.ch";
      access = {
        "katarina-agent@dia".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM4bLcT6GIZQNpU4N5ihA0nfkj6cdZYEJgKElgR9dVOm";
      };
      sign = { };
    };
    barsick = {
      email = "barsick@futureware.dev";
      access = {
        "barsick@nas".publicKey =
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0uhV/tABH5lpaJjH+jvNYj9bAa4O63TAT+hWdwCrMK";
      };
      sign = { };
    };
  };

  hostKeys = {
    "git.home.arpa".rsa.publicKey =
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDwfA6BEClvgqiQrOU6Bm5oxqXaFZ0zkgsJ0Hi5NzT4shXTRhqHeHjnxJlcL191Sd+46oX4wTg4fp2W1f6JtMloNnbvnGSgdzDv0zGMU3zFcCiYR202+xV9iOvR6SkCmhArfRgiWD7n7umjFNYsCYgkUzZ93Ot3qaCdvx7sn7IUFCZdd5PzR11JBOpxlU/bgG3nktOn28R5mfyoimm4nKQDmKkvwy3kQZ+0iCRjUc4g1xZaizhKeFEns+GjNfUgWfk27yQ6H02oFfBPf9v47UxJ0/dUtCswoVrU60zPqVfWE9qoo/Zu2wbMVnu+CK7MW2XyctzHsjYp3A+pHeB1rCtUi6jugist4y6fdn4vu5HDW4eXFk+6G94zJQF9ueojzv9488pt5OKkO6+VPxpNMxikduTvMOPk1FxyxJL8ZLND4WF6CS3rejDUB8hG2eqEdIZI55VX4Zp7yHOhmMpjz8R1Lx2uRx/kcqYb6pomvIWxKsVEIQpueyR/icsliPw3Kv9fHKrFW1w/jYbWnUA2SnYBziwwD2eA7jgsekQoDPtXwE37YkhZ21xBQqXoLYIb9fSHKo95jyOKHUAWI/AT4X1aoAEzoqRCrb3ENz85F81yhpNHtOs67MrPUl2XAxjXfCgwOhgu4bJSizHl3/8GAngDNwSfCoWMjR+HolZZ1Uezmw=="; # pragma: allowlist secret
  };
}
