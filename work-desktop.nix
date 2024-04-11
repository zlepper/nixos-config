{ config, pkgs, ... }:

{
  imports = [
    ./work-desktop-hardware.nix
    ./configuration.nix
  ];

  networking.hostName = "rhdh-work-desktop";
}
