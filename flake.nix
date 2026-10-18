{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, using the nixos-23.11 branch here
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    unstableNixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      # The `follows` keyword in inputs is used for inheritance.
      # Here, `inputs.nixpkgs` of home-manager is kept consistent with
      # the `inputs.nixpkgs` of the current flake,
      # to avoid problems caused by different versions of nixpkgs.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    styrhous = {
      url = "github:zlepper/styrhous";
      inputs.nixpkgs.follows = "unstableNixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      unstableNixpkgs,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      unstablePkgs = import unstableNixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      allInputs = inputs // {
        unstable = unstablePkgs;
      };

      mkHost =
        hostModule:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = allInputs;
          modules = [
            hostModule
            ./home-manager-module.nix
          ];
        };
    in
    {
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;

      nixosConfigurations = {
        rhdh-work-desktop = mkHost ./work-desktop.nix;
        home-laptop = mkHost ./home-laptop.nix;
        home-desktop = mkHost ./home-desktop.nix;
        home-laptop-2 = mkHost ./home-laptop-2.nix;
      };
    };
}
