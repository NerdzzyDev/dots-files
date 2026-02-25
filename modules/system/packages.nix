{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    git
    neovim
    kitty
    firefox
    brightnessctl
    blueman
    swaylock
    vscodium
    vicinae
    pavucontrol
    pamixer
    pulseaudio
    sing-box
    noisetorch
    gnome-screenshot
    pciutils
    ffmpeg
    rocmPackages.clr.icd
    intel-compute-runtime
    gst_all_1.gstreamer
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly
    chromium
    bitwarden-cli
    gcc
    google-chrome
    zoom-us
    moonlight-qt
    transmission_4-gtk
    uv
  ];

  programs.noisetorch.enable = true;
}

