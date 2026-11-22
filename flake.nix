{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # The prebuilt nix-index database, which is what makes `,` usable: comma
    # maps a command name to the package providing it by asking nix-locate,
    # and nix-locate needs that database. nixpkgs' own programs.nix-index
    # would make this machine build the index itself -- a scan of every file
    # in nixpkgs, on four threads, repeated after each update. This input is
    # the same index already built and regenerated upstream, so it arrives as
    # a download and refreshes with `nix flake update`.
    #
    # follows pins it to the nixpkgs above rather than letting it pull a
    # second copy of the tree into the lock file.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-index-database,
      ...
    }:
    {
      nixosConfigurations.x395 = nixpkgs.lib.nixosSystem {
        modules = [
          ./configuration.nix
          # Installs the database above and the option that turns on comma;
          # configuration.nix enables it.
          nix-index-database.nixosModules.nix-index
          # Record the git commit this system was built from, shown by
          # `nixos-version --configuration-revision`. A build from a tree with
          # uncommitted changes records the commit hash suffixed with "-dirty".
          { system.configurationRevision = self.rev or self.dirtyRev or null; }
        ];
      };

      # `nix fmt` formats every .nix file in the repository with nixfmt.
      # hooks/pre-commit runs it on each commit.
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
    };
}
