{ pkgs, unstable, jetbrainsUpdated, lib, ... }:

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
    url =
      "https://digizuitedistribution.blob.core.windows.net/ffmpeg/7.0.2/ffmpeg-n7.0.2-linux64-gpl-7.0.tar.xz";
    hash = "sha256-OLz5p7A1OBmniuPHqK4tsA7zYWH4WYuMEL3AmvgaSbo=";
  };

  rid = jetbrainsUpdated.jetbrains.rider.override {
      forceWayland = true;
  };


  riderWithMediaInfo = pkgs.symlinkJoin {
    name = "rider";
    paths = [ rid ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rider \
        --suffix "LD_LIBRARY_PATH" : "${runtimeDeps}" \
        --suffix "PATH" : "${
          lib.strings.makeBinPath [
            pkgs.ghostscript
            ffmpegZip
            pkgs.imagemagickBig
            pkgs.libreoffice
            pkgs.exiftool
            pkgs.inkscape
          ]
        }" \
        --set "COREFONTS_PATH" "${pkgs.corefonts}/share/fonts/truetype" \
        --set "FONTCONFIG_PATH" "/etc/fonts" \
        --set "TZ" "Etc/UTC" \
        --set "LC_ALL" "en_US.UTF-8"
    '';
  };
in {

  home.packages = [
    (with pkgs.dotnetCorePackages; combinePackages [ sdk_8_0 sdk_7_0 sdk_9_0 ])
    riderWithMediaInfo
  ];
}
