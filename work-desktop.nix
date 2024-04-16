{ config, pkgs, ... }:

{
  imports = [
    ./work-desktop-hardware.nix
    ./enable-nvidia-drivers.nix
    ./configuration.nix
  ];

  networking.hostName = "rhdh-work-desktop";
}
