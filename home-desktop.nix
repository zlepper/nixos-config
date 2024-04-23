{ ... }:

{
  imports = [ ./hardware/home-desktop.nix ./configuration.nix ./gaming.nix ];

  networking.hostName = "home-desktop";

  use-home-manager.enable = true;
}
