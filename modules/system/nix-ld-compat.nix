{ pkgs, ... }:

{
  # Runtime compatibility layer for prebuilt binaries (npm/electron/appimages).
  # This does not start any background services; it only exposes shared libs.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      glib
      gdk-pixbuf
      gtk3
      nss
      nspr
      atk
      at-spi2-atk
      at-spi2-core
      libnotify
      pango
      cairo
      harfbuzz
      freetype
      fontconfig
      alsa-lib
      dbus
      systemd
      udev
      libdrm
      libgbm
      libglvnd
      vulkan-loader
      mesa
      wayland
      libxkbcommon
      cups
      expat

      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxinerama
      libxi
      libxrandr
      libxcb
      libXcursor
      libXrender
      libxscrnsaver
      libxtst
      libxshmfence
    ];
  };
}
