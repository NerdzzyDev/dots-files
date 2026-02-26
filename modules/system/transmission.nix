{ config, lib, pkgs, ... }:

{
  ########################
  ## Transmission GUI
  ########################
  environment.systemPackages = with pkgs; [
    transmission_4-gtk  # полноценное GUI приложение
  ];

  ########################
  ## Transmission Daemon + Web UI
  ########################
  services.transmission = {
    enable = true;
    package = pkgs.transmission_4;
    openFirewall = true;

    settings = {
      download-dir = "/home/alex/Downloads/torrents";
      incomplete-dir-enabled = true;
      incomplete-dir = "/home/alex/Downloads/torrents/.incomplete";

      rpc-authentication-required = false; 
      rpc-whitelist-enabled = false;

      # Скорости можно подкрутить
      speed-limit-up = 2000;
      speed-limit-up-enabled = true;
      speed-limit-down = 8000;
      speed-limit-down-enabled = true;
    };
  };

  # Keep installed but do not auto-start at boot; start on GUI launch.
  systemd.services.transmission.wantedBy = lib.mkForce [ ];
}
