{ pkgs, ... }: {
  home.packages = [ pkgs.nodejs_22 pkgs.jetbrains.webstorm ];
}
