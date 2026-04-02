{ pkgs, ... }:

{
  ## ------------------------------------
  ## Meetily build dependencies (Linux)
  ## ------------------------------------
  environment.systemPackages = with pkgs; [
    # Toolchain
    rustc
    cargo
    rustfmt
    cmake
    pkg-config
    clang
    llvmPackages.libclang
    gnumake
    ninja

    # Tauri / WebView runtime + build deps
    gtk3
    gtk3.dev
    atk.dev
    alsa-lib
    alsa-lib.dev
    pango.dev
    cairo.dev
    gdk-pixbuf.dev
    harfbuzz.dev
    fribidi.dev
    fontconfig.dev
    libxkbcommon.dev
    wayland.dev
    vulkan-loader
    vulkan-headers
    shaderc
    openblas
    openblas.dev
    onnxruntime
    zlib
    zlib.dev
    webkitgtk_4_1
    webkitgtk_4_1.dev
    libsoup_3
    libsoup_3.dev
    libayatana-appindicator
    librsvg
    librsvg.dev
    openssl
    openssl.dev
  ];
}
