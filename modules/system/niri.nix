{ config, pkgs, ... }:
{
  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    displayManager.autoLogin.enable = true;
    displayManager.autoLogin.user = "alex";
  };

  programs.niri.enable = true;
}

