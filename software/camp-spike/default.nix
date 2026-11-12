# Root helpers for the CAMP agent-runtime spike
# (keyshot-coding-agent-platform/spikes/agent-runtime/helpers). The scripts are
# copied into this repo on purpose: sudo must only ever run reviewed,
# root-owned copies from the store, never the user-writable ones in the spike.
{ pkgs, ... }:

let
  # inheritPath = false: sudo keeps the caller's PATH (NixOS sets no secure_path),
  # so anything not in runtimeInputs would otherwise resolve to a user-writable
  # profile and run as root.
  campBenchShield = pkgs.writeShellApplication {
    name = "camp-bench-shield";
    inheritPath = false;
    runtimeInputs = with pkgs; [ coreutils gnugrep util-linux getent ];
    text = builtins.readFile ./camp-bench-shield;
  };
  campBtrfs = pkgs.writeShellApplication {
    name = "camp-btrfs";
    inheritPath = false;
    runtimeInputs = with pkgs; [ coreutils util-linux btrfs-progs ];
    text = builtins.readFile ./camp-btrfs;
  };
  nopasswd = pkg: {
    command = "${pkg}/bin/${pkg.name}";
    options = [ "NOPASSWD" ];
  };
in
{
  environment.systemPackages = [ campBenchShield campBtrfs ];

  security.sudo.extraRules = [
    {
      users = [ "rasmus" ];
      commands = [ (nopasswd campBenchShield) (nopasswd campBtrfs) ];
    }
  ];

  # camp-btrfs refuses to receive unless this directory exists on /data.
  systemd.tmpfiles.rules = [ "d /data/camp/btrfs-cmp 0755 rasmus users -" ];
}
