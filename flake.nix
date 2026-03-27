{
  description = "Shared Nix settings (NixOS, Home Manager etc)";

  outputs = { self }: {
    nixosModules = {
      nix-settings = import ./modules/nix-settings.nix;
      nix-gc = import ./modules/nix-gc.nix;
    };
  };
}
