{
  lib,
  config,
  unstable,
  home-manager,
  username,
  ...
}:

{
  imports = [ home-manager.nixosModules.home-manager ];

  options.use-home-manager.enable = lib.mkEnableOption "enable home manager with my settings";

  config = lib.mkIf config.use-home-manager.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      # I would put this elsewhere
      users.${username} = import ./home.nix;
      extraSpecialArgs = { inherit unstable; };
    };
  };
}
