{ ... }:

{
  imports = [ ./hardware/home-laptop.nix ./configuration.nix ./gaming.nix ];

  networking.hostName = "home-laptop";
}
