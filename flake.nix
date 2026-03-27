{
  description = "Shared Nix settings (NixOS, Home Manager etc)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    systems.url = "github:nix-systems/default";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      git-hooks,
      ...
    }:
    let
      eachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      nixosModules = {
        nix-settings = import ./modules/nix-settings.nix;
        nix-gc = import ./modules/nix-gc.nix;
        futureware = import ./modules/futureware.nix;
        tools = import ./modules/tools.nix;
      };

      lib.pre-commit = import ./pre-commit.nix;

      checks = eachSystem (system: {
        pre-commit-check = git-hooks.lib.${system}.run {
          src = ./.;
          inherit (self.lib.pre-commit) hooks;
        };
      });

      devShells = eachSystem (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          inherit (self.checks.${system}.pre-commit-check) shellHook enabledPackages;
        in
        {
          default = pkgs.mkShell {
            packages = enabledPackages;
            inherit shellHook;
          };
        }
      );
    };
}
