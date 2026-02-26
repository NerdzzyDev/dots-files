{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];


  nix.settings = {
    experimental-features = [ "flakes" "nix-command" ];
    # Faster failure when one protocol/path is broken (for example flaky IPv6).
    connect-timeout = 5;
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  users.users.alex = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "fuse"];
    shell = pkgs.zsh;
  };

  boot.kernelModules = [ "fuse" ];

  environment.systemPackages = with pkgs; [
    fuse2
  ];


  
  services.xserver.videoDrivers = [ "intel" ];

  hardware.graphics = {
  enable = true;
  enable32Bit = true;
  extraPackages = with pkgs; [
    intel-compute-runtime
    intel-media-driver   # VAAPI для Intel
    libva-vdpau-driver
    libvdpau-va-gl
  ];
  };
  #nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.05";
}
