{ config, pkgs, ... }:

{
  imports = [
    ./home-laptop-hardware.nix
    ./enable-nvidia-drivers.nix
    ./configuration.nix
  ];

  networking.hostName = "home-laptop";
}
