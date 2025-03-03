{ pkgs, ... }:

{
  imports = [ ];

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [ kdePackages.bluedevil ];

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot =
    true; # powers up the default Bluetooth controller on boot

  # Bluetooth does not enable correctly. See https://github.com/NixOS/nixpkgs/issues/170573#issuecomment-1118287349
  # for more information on this.
  systemd.tmpfiles.rules = [ "d /var/lib/bluetooth 700 root root - -" ];
  systemd.targets."bluetooth".after = [ "systemd-tmpfiles-setup.service" ];

  systemd.services."bluetooth".serviceConfig = {
    StateDirectory = ""; # <<< minimal solution, applied in override.conf

    # Seems unnecessary, but useful to keep in mind if bluetooth
    # defaults get locked down even more:
    # ReadWritePaths="/persist/var/lib/bluetooth/";
  };
}
