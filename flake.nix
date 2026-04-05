{
  description = "ASHBORN099's Professional NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # CRITICAL: We are adding Home Manager as a direct input
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs: {
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        ./hosts/default/hardware-configuration.nix
        # Connect Home Manager to the NixOS module system
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # Ensure this matches your username in configuration.nix
          home-manager.users.ilyamiro = import ./home.nix;
        }
      ];
    };
  };
}