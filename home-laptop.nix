{ config, pkgs, ... }:

{
  imports = [
    ./home-laptop-hardware.nix
    ./enable-nvidia-drivers.nix
    ./bluetooth.nix
    ./configuration.nix
  ];

  networking.hostName = "home-laptop";
}
