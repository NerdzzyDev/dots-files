{ pkgs, ... }:

{
  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.05";

  programs.zsh.enable = true;
  programs.zsh.shellAliases = {
    nsw = "sudo nixos-rebuild switch --flake ~/dots-files#nixos";
    hmsw = "home-manager switch --flake ~/dots-files#alex";

    sbstart = "sudo systemctl start sing-box";
    sbstop = "sudo systemctl stop sing-box";
    sbrestart = "sudo systemctl restart sing-box";
    sbstatus = "systemctl status sing-box";

    dockstart = "sudo systemctl start docker";
    dockstop = "sudo systemctl stop docker";
    dockstatus = "systemctl status docker";

    pgstart = "sudo systemctl start postgresql";
    pgstop = "sudo systemctl stop postgresql";
    pgstatus = "systemctl status postgresql";

    vmstart = "sudo systemctl start libvirtd";
    vmstop = "sudo systemctl stop libvirtd";
    vmstatus = "systemctl status libvirtd";

    codex-proxy = "ALL_PROXY=socks5h://127.0.0.1:2080 codex";
  };
  programs.zsh.initContent = ''
    # Auto-start local postgres when running psql (only for local sockets/localhost).
    psql() {
      local host="${PGHOST:-}"
      if [ -z "$host" ] || [ "$host" = "localhost" ] || [[ "$host" = /* ]]; then
        if ! systemctl is-active --quiet postgresql 2>/dev/null; then
          sudo systemctl start postgresql >/dev/null 2>&1 || true
        fi
      fi
      command psql "$@"
    }

    # Start transmission daemon on GUI open.
    transmission-gtk() {
      if ! systemctl is-active --quiet transmission 2>/dev/null; then
        sudo systemctl start transmission >/dev/null 2>&1 || true
      fi
      command transmission-gtk "$@"
    }

    # Start libvirtd when launching virt-manager.
    virt-manager() {
      if ! systemctl is-active --quiet libvirtd 2>/dev/null; then
        sudo systemctl start libvirtd >/dev/null 2>&1 || true
      fi
      command virt-manager "$@"
    }
  '';
  # programs.ohMyZsh.enable = true;
  #programs.zsh.ohMyZsh.theme = "muse";
  #programs.zsh.ohMyZsh.plugins = [ "git" "sudo" "docker" "zsh-autosuggestions" "zsh-syntax-highlighting"];

  home.sessionVariables.SHELL = "${pkgs.zsh}/bin/zsh";

  # ===== Packages =====
  home.packages = with pkgs; [
    htop
    fastfetch
    mpv
    slurp
    gsettings-desktop-schemas
    tree
    glib
    pywalfox-native
    flatpak
    obs-studio
    vlc
  ];

  # ===== Noctalia =====
  programs.noctalia-shell.enable = true;
  

  systemd.user.services.vicinae = {
  Unit = {
    Description = "Vicinae Launcher Daemon";
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
  };
  Service = {
    ExecStart = "${pkgs.vicinae}/bin/vicinae server";
    Restart = "always";
    RestartSec = 5;
    KillMode = "process";
  };
  Install = {
    WantedBy = [ "graphical-session.target" ];
  };
 };

  home.file.".config/flatpak/remotes.d/flathub.flatpakrepo".text = ''
        [Remote "flathub"]
        Url=https://flathub.org/repo/flathub.flatpakrepo
        Enabled=true
      '';

  # Disable unwanted autostarts
  home.file.".config/autostart/Pluely.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Pluely
    Hidden=true
  '';
  home.file.".config/autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';


  # Автоматическая установка Flatpak приложений
      home.sessionVariables.FLATPAK_APPS = ''
        com.dec05eba.gpu_screen_recorder
        org.freedesktop.Platform.GL.default//23.08-extra
      '';

#  programs.vicinae = {
#        enable = true; # default: false
#    };

}
