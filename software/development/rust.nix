{ pkgs, unstable, lib, ... }:

let
  runtimeDeps = lib.makeLibraryPath [ pkgs.libpcap ];

  rr =  unstable.jetbrains.rust-rover.override {
       forceWayland = true;
    }; 

  rust-rover = pkgs.symlinkJoin {
    name = "rust-rover";
    paths = [rr];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rust-rover \
        --suffix "LIBPCAP_LIBDIR" : "${runtimeDeps}" \
    '';
  };
in { home.packages = [ rust-rover pkgs.rustup pkgs.clang pkgs.heaptrack pkgs.cargo-expand pkgs.gnumake ]; }

