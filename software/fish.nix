{ pkgs, ... }:

{

  programs.fish.enable = true;
  programs.bash = {
    # Hand interactive bash over to fish, except for the bash that `nix develop` / `nix-shell`
    # start (`bash --rcfile .../nix-shell.XXXXXX`), whose shellHook would otherwise never run.
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" \
            && -z ''${BASH_EXECUTION_STRING} \
            && $(${pkgs.procps}/bin/ps --no-header --pid=$$ --format=args) != *"--rcfile "*"/nix-shell."* ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

}
