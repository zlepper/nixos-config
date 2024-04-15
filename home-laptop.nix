{ config, pkgs, ... }:

{
  imports = [
    ./home-laptop-hardware.nix
    ./configuration.nix
  ];

  networking.hostName = "home-laptop";
}
