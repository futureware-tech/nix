_:

{
  nixpkgs.overlays = [
    (final: _prev: {
      git-safe-sync = final.callPackage ../packages/git-safe-sync.nix { };
    })
  ];
}
