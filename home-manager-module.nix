{ lib, config, unstable, rust-span-counter, home-manager, ... }:

{
  imports = [ home-manager.nixosModules.home-manager ];

  options.use-home-manager.enable =
    lib.mkEnableOption "enable home manager with my settings";

  config = lib.mkIf config.use-home-manager.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # I would put this elsewhere
      users.rasmus = import ./home.nix;
      extraSpecialArgs = { inherit unstable rust-span-counter; };
    };
  };
}

