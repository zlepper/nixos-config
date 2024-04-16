{ config, pkgs, ... }:

{
  imports = [
    ./work-desktop-hardware.nix
    ./enable-nvidia-drivers.nix
    ./bluetooth.nix
    ./configuration.nix
  ];

  networking.hostName = "rhdh-work-desktop";
}
