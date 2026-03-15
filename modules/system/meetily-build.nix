{ pkgs, ... }:

{
  ## ------------------------------------
  ## Meetily build dependencies (Linux)
  ## ------------------------------------
  environment.systemPackages = with pkgs; [
    # Toolchain
    rustc
    cargo
    cmake
    pkg-config
    clang
    llvmPackages.libclang

    # Tauri / WebView runtime + build deps
    gtk3
    webkitgtk_4_1
    libsoup_3
    libayatana-appindicator
    librsvg
    openssl
  ];
}
