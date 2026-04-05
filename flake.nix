{
  description = "ASHBORN099's Professional NixOS Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # WE ARE ADDING THIS LINE:
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
        # AND THIS LINE TO CONNECT HOME-MANAGER:
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # Change 'tester' to your username if you aren't using the script's default
          home-manager.users.tester = import ./home.nix;
        }
      ];
    };
  };
}