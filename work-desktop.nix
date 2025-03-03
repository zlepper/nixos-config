{ pkgs, unstable, lib, ... }:

let
  # Don't install the individual provider packages as we install them directly
  # as part of our automation scripts.
  pulumi = unstable.pulumi-bin.overrideAttrs (finalAtrs: previousAttrs: {
	srcs = lib.lists.take 1 previousAttrs.srcs;
        postUnpack = "";
  });
in {
  imports = [ ./hardware/work-desktop.nix ./configuration.nix ];

  networking.hostName = "rhdh-work-desktop";

  environment.systemPackages = with pkgs; [
      lens
      meshlab
      imagemagick 
      flyctl
      slack
      filezilla
      postman
      snyk
    ] ++ [pulumi];
  use-home-manager.enable = true;
  services.envfs.enable = true;

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
