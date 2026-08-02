{unstable, ...}:

let
  instructions = builtins.readFile ./code-agent-instructions.md;
in
{
  home.file.".config/github-copilot/intellij/global-copilot-instructions.md".text = instructions;
  home.file.".claude/CLAUDE.md".text = instructions;
  home.file.".codex/AGENTS.md".text = instructions;

  home.packages = [ unstable.codex ];
}
