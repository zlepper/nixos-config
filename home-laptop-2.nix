{ ... }:

{
  imports = [ ./hardware/home-laptop-2.nix ./configuration.nix ];

  networking.hostName = "home-laptop-2";

  use-home-manager.enable = true;
 
  system.stateVersion = "25.05";
}
