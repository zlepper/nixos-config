{ unstable, pkgs, ... }:

{
  imports = [ ./hardware/home-desktop.nix ./configuration.nix ./gaming.nix ];

  networking.hostName = "home-desktop";

  environment.systemPackages = with pkgs; [ lens freecad postman unstable.claude-code mono unstable.gemini-cli ];
  use-home-manager.enable = true;
}
