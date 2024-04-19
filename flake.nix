{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    unstableNixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    writersidePrNixpkgs.url = "github:zlepper/nixpkgs/init-jetbrains-writeside";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.11";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, unstableNixpkgs, writersidePrNixpkgs, ... }@inputs:
  let
      unstablePkgs = import unstableNixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
      writersidePrPkgs = import writersidePrNixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };
  in {

    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;


    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix

        # make home-manager as a module of nixos
        # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.rasmus = import ./home.nix;
          home-manager.extraSpecialArgs = {
            unstable = unstablePkgs;
            writerside = writersidePrPkgs;
          };
        }
      ];
    };

    nixosConfigurations.nixos-hyperv-vm = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./configuration.nix

        ./hyper-vm-hardware-configuration.nix

        # make home-manager as a module of nixos
        # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.rasmus = import ./home.nix;

          home-manager.extraSpecialArgs = {
            unstable = unstablePkgs;
            writerside = writersidePrPkgs;
          };
        }
      ];
    };

    nixosConfigurations.rhdh-work-desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./work-desktop.nix

        # make home-manager as a module of nixos
        # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.rasmus = import ./home.nix;

          home-manager.extraSpecialArgs = {
            unstable = unstablePkgs;
            writerside = writersidePrPkgs;
          };
        }
      ];
    };

    nixosConfigurations.home-laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = inputs // {
        unstable = unstablePkgs;
        writerside = writersidePrPkgs;
      };
      modules = [
        # Import the previous configuration.nix we used,
        # so the old configuration file still takes effect
        ./home-laptop.nix
        ./home-manager-module.nix
/*
        # make home-manager as a module of nixos
        # so that home-manager configuration will be deployed automatically when executing `nixos-rebuild switch`
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.extraSpecialArgs = {
            unstable = unstablePkgs;
            writerside = writersidePrPkgs;
          };
          home-manager.users.rasmus = import ./home.nix;
        }*/
      ];
    };
  };
}
