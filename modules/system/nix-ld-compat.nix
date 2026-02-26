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
      gtk3
      nss
      nspr
      atk
      at-spi2-atk
      at-spi2-core
      pango
      cairo
      alsa-lib
      dbus
      libdrm
      mesa
      libxkbcommon
      cups
      expat

      libx11
      libxcomposite
      libxdamage
      libxext
      libxfixes
      libxi
      libxrandr
      libxcb
      libxscrnsaver
      libxtst
      libxshmfence
    ];
  };
}
