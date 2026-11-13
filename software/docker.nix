{ pkgs, ... }:

{

  #virtualisation.docker.enable = true;
  #virtualisation.docker.rootless = {
  #  enable = true;
  #  setSocketVariable = true;
  #};
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # Makes podman drop-in compatible with docker CLI
    defaultNetwork.settings.dns_enabled = true; # Required for kind DNS
  };

  # Rootless podman puts every container's session keyring on the user's key quota (default 200 keys).
  # Many kind nodes plus Testcontainers exhaust it ("unable to create session key: disk quota exceeded").
  boot.kernel.sysctl = {
    "kernel.keys.maxkeys" = 2000;
    "kernel.keys.maxbytes" = 2000000;
  };

  environment.systemPackages = [
    pkgs.kind
    pkgs.podman-compose
  ];

}
