{
  lib,
  config,
  unstable,
  home-manager,
  nuget-secret-cli-credentials,
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
      sharedModules = [ nuget-secret-cli-credentials.homeManagerModules.default ];
      extraSpecialArgs = { inherit unstable; };
    };
  };
}
