{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.resourceLimits;
  properties =
    [
      "Delegate=yes"
      "CPUWeight=10"
      "IOWeight=10"
    ]
    ++ lib.optional (cfg.memoryHigh != null) "MemoryHigh=${cfg.memoryHigh}"
    ++ lib.optional (cfg.memoryMax != null) "MemoryMax=${cfg.memoryMax}"
    ++ lib.optional (cfg.cpuCores != null) "CPUQuota=${toString (cfg.cpuCores * 100)}%";
  lowPriorityCommand = pkgs.writeShellScriptBin "lowprio" ''
    ${cfg.runPrefix} -- "$@"
  '';
in
{
  options.resourceLimits = with lib; {
    memoryHigh = mkOption {
      type = types.nullOr types.str;
      default = "30G";
      description = "MemoryHigh for low-priority scopes (lowprio, claude, codex). null disables it.";
    };
    memoryMax = mkOption {
      type = types.nullOr types.str;
      default = "32G";
      description = "MemoryMax for low-priority scopes. null disables it.";
    };
    cpuCores = mkOption {
      type = types.nullOr types.ints.positive;
      default = null;
      description = "Number of cores' worth of CPU time (CPUQuota) the whole scope may use. null means unlimited.";
    };
    runPrefix = mkOption {
      type = types.str;
      readOnly = true;
      internal = true;
      description = "Shell snippet that execs the rest of the line in a low-priority scope; append `-- <command>`.";
    };
  };

  config = {
    resourceLimits.runPrefix = ''
      export CONTAINERS_CONF_OVERRIDE=/etc/containers/lowprio.conf
      ${lib.optionalString (cfg.cpuCores != null) ''
        # .NET only reads the CPU quota of its own cgroup, so pin it for nested cgroups too
        export DOTNET_PROCESSOR_COUNT=${toString cfg.cpuCores}
      ''}
      # Private MSBuild node / compiler server pool per invocation, so builds neither use
      # workers outside this scope nor share them with other low-priority instances
      export MSBUILDNODEHANDSHAKESALT="lowprio-$$"
      export SharedCompilationId="lowprio-$$"
      exec ${pkgs.systemd}/bin/systemd-run --user --scope --quiet ${
        lib.escapeShellArgs (lib.concatMap (p: [ "-p" p ]) properties)
      }'';

    home.packages = [ lowPriorityCommand ];
  };
}
