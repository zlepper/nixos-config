{
  pkgs,
  unstable,
  lib,
  styrhous,
  ...
}:

let
  # Don't install the individual provider packages as we install them directly
  # as part of our automation scripts.
  pulumi = unstable.pulumi-bin.overrideAttrs (finalAtrs: previousAttrs: {
    srcs = lib.lists.take 1 previousAttrs.srcs;
    postUnpack = "";
  });
  
  claude-code = (pkgs.writeShellScriptBin "claude" ''
      export CONTAINERS_CONF_OVERRIDE=/etc/containers/lowprio.conf
      exec ${pkgs.systemd}/bin/systemd-run --user --scope --quiet \
        -p Delegate=yes -p CPUWeight=10 -p IOWeight=10 \
        -p MemoryHigh=30G -p MemoryMax=32G \
        -- ${unstable.claude-code}/bin/claude "$@"
    '');

in {
  imports = [
    ./hardware/work-desktop.nix
    ./configuration.nix
    ./hardware/virtualization.nix
    ./software/intune.nix
  ];

  networking.hostName = "rhdh-work-desktop";

  use-home-manager.enable = true;

  # Some software (e.g. prebuilt Qt's QSysInfo::machineUniqueId()) only reads the D-Bus machine ID
  # path. Other distributions link it to /etc/machine-id; NixOS doesn't create it.
  systemd.tmpfiles.rules = [ "L+ /var/lib/dbus/machine-id - - - - /etc/machine-id" ];

  environment.systemPackages = with pkgs;
    [
      lens
      styrhous.packages.${pkgs.stdenv.hostPlatform.system}.default
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
      claude-code
      ripgrep
      msbuild-structured-log-viewer
      teams-for-linux
      awscli2
      pulumi
      killall
      unstable.github-copilot-cli
    ];

  environment.etc."containers/lowprio.conf".text = ''
    [containers]
    cgroups = "split"
  '';

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
}
