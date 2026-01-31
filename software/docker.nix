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

  environment.systemPackages = [pkgs.kind pkgs.podman-compose];

}
