{ pkgs, lib, ... }:

let
  runtimeDeps = lib.makeLibraryPath [ pkgs.libpcap ];

  rust-rover = pkgs.symlinkJoin {
    name = "rust-rover";
    paths = [ pkgs.jetbrains.rust-rover ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rust-rover \
        --suffix "LIBPCAP_LIBDIR" : "${runtimeDeps}" \
    '';
  };
in { home.packages = [ rust-rover pkgs.rustup pkgs.clang pkgs.heaptrack pkgs.cargo-expand ]; }

