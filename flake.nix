{
  description = "ASHBORN099's Professional NixOS Flake";

  inputs = {
    # We use the 'unstable' branch for the latest AI/Python packages
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    # This 'default' name must match the one in your install.sh
    nixosConfigurations.default = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./configuration.nix
        # The installer will automatically create the hardware-configuration.nix
        ./hosts/default/hardware-configuration.nix 
      ];
    };
  };
}