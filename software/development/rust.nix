{unstable, pkgs, ...}:
{
    home.packages = [
        pkgs.rustup
        pkgs.clang
        unstable.jetbrains.rust-rover
    ];
}
