{ username, ... }:

{
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "client";
  # extraUpFlags only apply with authKeyFile; `tailscale set` runs on every boot/switch.
  services.tailscale.extraSetFlags = [
    "--operator=${username}"
    "--ssh"
    "--accept-routes"
  ];
}
