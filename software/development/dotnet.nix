{unstable, pkgs, lib, ...}:

let
 runtimeDeps = lib.makeLibraryPath [
    pkgs.libmediainfo
 ];

 riderWithMediaInfo = pkgs.symlinkJoin {
    name = "rider";
    paths = [ unstable.jetbrains.rider ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
        wrapProgram $out/bin/rider \
          --suffix "LD_LIBRARY_PATH" : "${runtimeDeps}"
    '';
    };
in {



    home.packages = [
        unstable.dotnetCorePackages.dotnet_8.sdk
        riderWithMediaInfo
    ];
}
