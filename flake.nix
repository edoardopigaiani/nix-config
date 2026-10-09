{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.x395 = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
