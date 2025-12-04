{ pkgs, unstable, lib, ... }:

let
  # Don't install the individual provider packages as we install them directly
  # as part of our automation scripts.
  pulumi = unstable.pulumi-bin.overrideAttrs (finalAtrs: previousAttrs: {
    srcs = lib.lists.take 1 previousAttrs.srcs;
    postUnpack = "";
  });
in {
  imports = [
    ./hardware/work-desktop.nix
    ./configuration.nix
    ./hardware/virtualization.nix
  ];

  networking.hostName = "rhdh-work-desktop";

  environment.systemPackages = with pkgs;
    [
      lens
      meshlab
      imagemagick
      flyctl
      slack
      filezilla
      postman
      snyk
      libreoffice-fresh
      wireshark
      kubernetes-helm
      jq
      python312
      virtualenv
      python312Packages.virtualenv
      openssl
      tmux
      pkgs.jetbrains.gateway
      gh
      unstable.claude-code
      ripgrep
      msbuild-structured-log-viewer
      teams-for-linux
    ] ++ [ pulumi ];
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11"; # Did you read the comment?
  boot.kernelPackages = pkgs.linuxPackages_latest;
}
