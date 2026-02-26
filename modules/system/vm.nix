{ config, lib, pkgs, ... }:

{
  # Add user to libvirtd group
  users.users.alex.extraGroups = [ "libvirtd" ];

  # Install necessary packages
  environment.systemPackages = with pkgs; [
    virt-manager
    virt-viewer
    spice spice-gtk
    spice-protocol
    virtio-win
    win-spice
  ];

  # Manage the virtualisation services
  virtualisation = {
    libvirtd = {
      enable = true;
      qemu = {
      };
    };
    spiceUSBRedirection.enable = true;
  };
  services.spice-vdagentd.enable = true;

  # Do not auto-start libvirtd on boot; start it when needed.
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];

}
