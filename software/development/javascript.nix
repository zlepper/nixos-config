{ pkgs, ... }: {
  home.packages = [ pkgs.nodejs_24 pkgs.jetbrains.webstorm ];
}
