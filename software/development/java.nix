{ pkgs, unstable, lib, ... }:

let 
  runtimeDeps = lib.makeLibraryPath [
	unstable.libxext
        unstable.xorg.libX11
        unstable.xorg.libICE
        unstable.xorg.libSM
	unstable.libxrender
	unstable.libxtst
        unstable.libxi
	unstable.openjdk
        unstable.freetype
        unstable.fontconfig
  ];

  idea = unstable.jetbrains.idea.override {
	forceWayland = true;
  };

  ideaWithDeps = pkgs.symlinkJoin {
	name = "idea";
  	paths = [idea];
  	buildInputs = [pkgs.makeWrapper];
	postBuild = ''
		wrapProgram $out/bin/idea \
			--suffix "LD_LIBRARY_PATH" : "${runtimeDeps}" \
			--suffix "PATH" : "${
				lib.strings.makeBinPath [
					pkgs.fontconfig
				]
			}" \
			--set "FONTCONFIG_FILE" "/etc/fonts/fonts.conf"
	'';
  };
in
 {
  
  home.packages = [ ideaWithDeps ];
}
