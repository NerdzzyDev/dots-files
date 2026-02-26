{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # Base CLI
    git
    neovim
    kitty
    pciutils

    # Desktop apps
    firefox
    chromium
    google-chrome
    vscodium
    zoom-us
    moonlight-qt
    gnome-screenshot
    ffmpeg
    telegram-desktop

    # System / audio / desktop helpers
    brightnessctl
    blueman
    pavucontrol
    pamixer
    sing-box
    noisetorch

    # Media codecs / pipelines
    gst_all_1.gstreamer
    gst_all_1.gst-libav
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-ugly

    # Utilities
    bitwarden-cli
  ];

  programs.noisetorch.enable = true;
}
