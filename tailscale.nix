{ config, pkgs, ... }:

{

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
  services.tailscale.extraUpFlags = [ "--ssh" ];
}
