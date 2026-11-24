{ pkgs, username, ... }:

{
  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = [ username ];

  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };

  virtualisation.spiceUSBRedirection.enable = true;

  boot.extraModprobeConfig = "options kvm_amd nested=1";

  #dconf.settings = {
  #"org/virt-manager/virt-manager/connections" = {
  #  autoconnect = ["qemu:///system"];
  #  uris = ["qemu:///system"];
  #};

}
