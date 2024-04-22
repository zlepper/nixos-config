{ pkgs, ... }:

{
  imports = [ ./hardware/work-desktop.nix ./configuration.nix ];

  networking.hostName = "rhdh-work-desktop";

  environment.systemPackages = with pkgs; [ ghostscript lens imagemagick ffmpeg libreoffice ];
  use-home-manager.enable = true;
}
