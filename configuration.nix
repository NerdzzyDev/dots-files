{ config, pkgs, ... }:

let
  nixDaemonProxyEnv = pkgs.writeShellApplication {
    name = "nix-daemon-proxy-env";
    runtimeInputs = [ pkgs.python3 pkgs.coreutils ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      env_file="/run/nix-daemon-proxy.env"

      if ${pkgs.python3}/bin/python3 - <<'PY'
import socket
import sys

try:
    conn = socket.create_connection(("127.0.0.1", 2080), timeout=0.5)
    conn.close()
except OSError:
    sys.exit(1)
PY
      then
        cat > "$env_file" <<'EOF'
ALL_PROXY=socks5h://127.0.0.1:2080
HTTP_PROXY=socks5h://127.0.0.1:2080
HTTPS_PROXY=socks5h://127.0.0.1:2080
NO_PROXY=localhost,127.0.0.1,::1
EOF
      else
        : > "$env_file"
      fi
    '';
  };
in

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

  systemd.services.nix-daemon.serviceConfig = {
    EnvironmentFile = [ "-/run/nix-daemon-proxy.env" ];
    ExecStartPre = [ "${nixDaemonProxyEnv}/bin/nix-daemon-proxy-env" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  users.users.alex = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "fuse" "video" ];
    shell = pkgs.zsh;
  };

  # vkms can expose a virtual DRM output for a presentation-only monitor.
  boot.kernelModules = [ "fuse" "vkms" ];

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
