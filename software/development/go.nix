{ pkgs, ... }: {
  home.packages = [ pkgs.go pkgs.jetbrains.goland ];
}
