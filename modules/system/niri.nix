{ config, pkgs, ... }:
{
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
  };
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "alex";

  programs.niri.enable = true;
}
