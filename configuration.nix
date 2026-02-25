{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];


  nix.settings.experimental-features = [ "flakes" "nix-command" ];

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
  programs.nix-ld.enable = true;

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

