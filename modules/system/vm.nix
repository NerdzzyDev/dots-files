{ config, lib, pkgs, ... }:

{
  # Add user to libvirtd group
  users.users.alex.extraGroups = [ "libvirtd" ];

  # Host-side folder shared with the Windows VM over SMB.
  # In the guest, open \\10.0.2.2\vmshare when the VM uses user-mode networking.
  systemd.tmpfiles.rules = [
    "d /home/alex/vm-share 0775 alex users -"
  ];

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

  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "security" = "user";
        "map to guest" = "Bad User";
        "server min protocol" = "SMB2";
        "guest account" = "alex";
        "interfaces" = "lo virbr0";
        "bind interfaces only" = "yes";
      };

      vmshare = {
        path = "/home/alex/vm-share";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "guest only" = "yes";
        "force user" = "alex";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
    };
  };

  networking.firewall.interfaces.virbr0.allowedTCPPorts = [ 139 445 ];
  networking.firewall.interfaces.virbr0.allowedUDPPorts = [ 137 138 ];

  # Do not auto-start libvirtd on boot; start it when needed.
  systemd.services.libvirtd.wantedBy = lib.mkForce [ ];

}
