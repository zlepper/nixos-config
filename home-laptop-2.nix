{ pkgs, unstable, ... }:

{
  imports = [ ./hardware/home-laptop-2.nix ./configuration.nix ];

  networking.hostName = "home-laptop-2";

  use-home-manager.enable = true;

  environment.systemPackages = [
     unstable.claude-code
     pkgs.ripgrep
  ];
 
  system.stateVersion = "25.05";
}
