{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    unstableNixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-span-counter = {
      url = "github:zlepper/rust-span-counter";
      inputs.nixpkgs.follows = "unstableNixpkgs";
    };
    jetbrainsUpdated.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, home-manager, unstableNixpkgs, rust-span-counter, jetbrainsUpdated, ... }@inputs:
    let
      unstablePkgs = import unstableNixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      jetbrainsUpdatedPkgs = import jetbrainsUpdated {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      allInputs = inputs // { 
        unstable = unstablePkgs;
        rust-span-counter = rust-span-counter.packages.x86_64-linux;
        jetbrainsUpdated = jetbrainsUpdatedPkgs;
      };

    in {

      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;

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
        modules = [ ./home-desktop.nix ./home-manager-module.nix ];
      };


      nixosConfigurations.home-laptop-2 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = allInputs;
        modules = [ ./home-laptop-2.nix ./home-manager-module.nix ];
      };


    };
}
