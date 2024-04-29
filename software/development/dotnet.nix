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
          --suffix "LD_LIBRARY_PATH" : "${runtimeDeps}" \
          --suffix "PATH" : "${lib.strings.makeBinPath [pkgs.ghostscript pkgs.ffmpeg pkgs.imagemagick pkgs.libreoffice pkgs.exiftool]}" \
          --suffix "COREFONTS_PATH" : "${pkgs.corefonts}/share/fonts/truetype" \
          --suffix "FONTCONFIG_PATH" : "/etc/fonts"
    '';
    };
in {



    home.packages = [
        (with unstable.dotnetCorePackages; combinePackages [dotnet_8.sdk sdk_7_0])
        riderWithMediaInfo
    ];
}
