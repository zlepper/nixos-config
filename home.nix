{ lib, pkgs, unstable, ... }:

let
  onePassPath = "/home/rasmus/.1password/agent.sock";
  unfuck-lfs-script = pkgs.writeShellScriptBin "unfuck-lfs" ''
    	git rm --cached -r .
            git reset --hard
            git rm .gitattributes
            git reset .
            git checkout .
  '';
in {

  imports = [
    ./software/development/dotnet.nix
    ./software/development/javascript.nix
    ./software/development/rust.nix
    ./software/development/go.nix
    ./software/development/java.nix
    ./software/llm.nix
  ];

  home.username = "rasmus";
  home.homeDirectory = "/home/rasmus";

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  home.file.".config/kate/lspclient/settings.json".text = ''
    {
      "servers": {
        "nix": {
          "command": ["nil"],
          "url": "https://github.com/oxalica/nil",
          "highlightingModeRegex": "^Nix$"
        }
      }
    }
  '';

  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    zip
    unzip
    which
    tree
    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring
    google-chrome
    spotify
    discord
    firefox
    kdePackages.kate
    dive
    tree
    remmina
    nil
    nix-tree
    xclip
    libtree
    pkgs.jetbrains.datagrip
    kubectl
    azure-cli
    vlc
    gimp
    unfuck-lfs-script
    qdirstat
    ripgrep
    obsidian
    rustdesk-flutter
    file
    dig
  ];

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    settings = {
      user = {
        email = "hansen13579@gmail.com";
        name = "zlepper";
      };
      push = { autoSetupRemote = true; };
      pull = { rebase = true; };
      gpg = {
        format = "ssh";
      };
      "gpg \"ssh\"" = {
        program = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
      };
      commit = {
        gpgsign = true;
      };

      user = {
        signingKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKEH6/ioXsJxKFJZMKx44HGT0iGOw4CQyCI/GYDPCGYZ";
      };
    };
    lfs.enable = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = false;
      addKeysToAgent = "no";
      compression = false;
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "~/.ssh/known_hosts";
      controlMaster = "no";
      controlPath = "~/.ssh/master-%r@%n:%p";
      controlPersist = "no";
    };
    extraConfig = ''
      Host *
          IdentityAgent ${onePassPath}
    '';
  };
  home.sessionVariables.SSH_AUTH_SOCK = onePassPath;

  services.gpg-agent = {
    enable = true;
    #extraConfig = "pinentry-program ${pkgs.pinentry-gtk2}/bin/pinentry";
  };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "23.11";

  # Let home Manager install and manage itself.
  programs.home-manager.enable = true;
}
