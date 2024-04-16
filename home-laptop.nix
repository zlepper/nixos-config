{ ... }:

{
  imports = [ ./hardware/home-laptop.nix ./configuration.nix ];

  networking.hostName = "home-laptop";
}
