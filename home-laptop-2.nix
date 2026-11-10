{ pkgs, unstable, ... }:

{
  imports = [
    ./hardware/home-laptop-2.nix
    ./configuration.nix
  ];

  networking.hostName = "home-laptop-2";

  use-home-manager.enable = true;

  environment.systemPackages = [
    pkgs.ripgrep
    pkgs.postman
    unstable.gh
  ];

  system.stateVersion = "25.05";
}
