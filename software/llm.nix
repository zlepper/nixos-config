{ pkgs, unstable, config, ... }:

let
  instructions = builtins.readFile ./code-agent-instructions.md;

  mkAgent = name: pkg: pkgs.writeShellScriptBin name ''
    ${config.resourceLimits.runPrefix} -- ${pkg}/bin/${name} "$@"
  '';
in
{
  home.file.".config/github-copilot/intellij/global-copilot-instructions.md".text = instructions;
  home.file.".claude/CLAUDE.md".text = instructions;
  home.file.".codex/AGENTS.md".text = instructions;

  home.packages = [
    (mkAgent "claude" unstable.claude-code)
    (mkAgent "codex" unstable.codex)
  ];
}
