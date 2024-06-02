{ pkgs, ... }:

{
  imports = [ ./hardware/home-desktop.nix ./configuration.nix ./gaming.nix ];

  networking.hostName = "home-desktop";

  environment.systemPackages = with pkgs; [
      lens
      freecad
    ];
  use-home-manager.enable = true;
}
