{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.x395 = nixpkgs.lib.nixosSystem {
      modules = [
        ./configuration.nix
        # Record the git commit this system was built from, shown by
        # `nixos-version --configuration-revision`. A build from a tree with
        # uncommitted changes records the commit hash suffixed with "-dirty".
        { system.configurationRevision = self.rev or self.dirtyRev or null; }
      ];
    };
  };
}
