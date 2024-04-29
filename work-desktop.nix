{ pkgs, unstable, ... }:

{
  imports = [ ./hardware/work-desktop.nix ./configuration.nix ];

  networking.hostName = "rhdh-work-desktop";

  environment.systemPackages = with pkgs; [
      lens
      meshlab
      unstable.ffmpeg_7-full
      unstable.imagemagick
    ];
  use-home-manager.enable = true;

  fonts = {
     enableDefaultPackages = true;
     packages = with pkgs; [
        noto-fonts
        corefonts
        caladea
        carlito
        helvetica-neue-lt-std
        liberation_ttf
     ];
  };
}
