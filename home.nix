{ config, pkgs, ... }:

let
  # onePassPath = "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";
  onePassPath = "~/.1password/agent.sock";
in {
  home.username = "rasmus";
  home.homeDirectory = "/home/rasmus";

  # encode the file content in nix configuration file directly
  # home.file.".xxx".text = ''
  #     xxx
  # '';


  # Packages that should be installed to the user profile.
  home.packages = with pkgs; [
    zip
    unzip
    ripgrep # recursively searches directories for a regex pattern
    eza # A modern replacement for ‘ls’
    dnsutils  # `dig` + `nslookup`
    which
    tree
    btop  # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # system call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files
    kgpg
  ];

  # basic configuration of git, please change to your own
  programs.git = {
    enable = true;
    userName = "zlepper";
    userEmail = "hansen13579@gmail.com";
  };

  programs.ssh = {
    enable = true;
    extraConfig = ''
      Host *
          IdentityAgent ${onePassPath}
    '';
  };

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
