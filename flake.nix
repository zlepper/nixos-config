{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    unstableNixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, unstableNixpkgs, ... }@inputs:
  let
      unstablePkgs = import unstableNixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };

      allInputs = inputs // {
        unstable = unstablePkgs;
      };

  in {

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;


    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix

        ./home-manager-module.nix
      ];
    };

    nixosConfigurations.nixos-hyperv-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix

        ./hyper-vm-hardware-configuration.nix

        ./home-manager-module.nix
      ];
    };

    nixosConfigurations.rhdh-work-desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = allInputs;
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./work-desktop.nix
        ./home-manager-module.nix
      ];
    };

    nixosConfigurations.home-laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = allInputs;
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./home-laptop.nix
        ./home-manager-module.nix
      ];
    };

    nixosConfigurations.home-desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = allInputs;
      modules = [
        ./home-desktop.nix
        ./home-manager-module.nix
      ];
    };
  };
}
