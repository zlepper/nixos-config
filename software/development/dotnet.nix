{unstable, pkgs, lib, ...}:

let
 runtimeDeps = lib.makeLibraryPath [
    pkgs.libmediainfo
    pkgs.xorg.libX11
    pkgs.xorg.libX11.dev
    pkgs.xorg.libICE
    pkgs.xorg.libSM
 ];

 ffmpegZip = pkgs.fetchzip {
    name = "ffmpeg-zip";
    url = "https://digizuitedistribution.blob.core.windows.net/ffmpeg/7.0.2/ffmpeg-n7.0.2-linux64-gpl-7.0.tar.xz";
    hash = "sha256-OLz5p7A1OBmniuPHqK4tsA7zYWH4WYuMEL3AmvgaSbo=";
 };

 riderWithMediaInfo = pkgs.symlinkJoin {
    name = "rider";
    paths = [ unstable.jetbrains.rider ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
        wrapProgram $out/bin/rider \
          --suffix "LD_LIBRARY_PATH" : "${runtimeDeps}" \
          --suffix "PATH" : "${lib.strings.makeBinPath [pkgs.ghostscript ffmpegZip pkgs.imagemagickBig pkgs.libreoffice pkgs.exiftool]}" \
          --suffix "COREFONTS_PATH" : "${pkgs.corefonts}/share/fonts/truetype" \
          --suffix "FONTCONFIG_PATH" : "/etc/fonts"
    '';
    };
in {



    home.packages = [
        (with unstable.dotnetCorePackages; combinePackages [sdk_8_0 sdk_7_0])
        riderWithMediaInfo
    ];
}
