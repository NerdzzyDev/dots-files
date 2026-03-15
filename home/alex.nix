{ lib, pkgs, ... }:

{
  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.05";

  programs.zsh.enable = true;
  # We run compinit manually with cached mode (-C) for faster prompt readiness.
  programs.zsh.enableCompletion = false;
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

    ppsave = "powerprofilesctl set power-saver";
    ppbal = "powerprofilesctl set balanced";
    ppperf = "powerprofilesctl set performance";
  };
  programs.zsh.initContent = ''
    mkdir -p "$HOME/.cache/zsh"
    autoload -U compinit
    compinit -C -d "$HOME/.cache/zsh/zcompdump-$ZSH_VERSION"

    nixos() {
      local cmd="$1"
      shift || true

      case "$cmd" in
        gc)
          echo "[nixos gc] Cleaning user + system generations, store GC, optimize store..."
          nix-collect-garbage -d || return $?
          sudo nix-collect-garbage -d || return $?
          home-manager expire-generations "-14 days" || true
          sudo nix store gc || return $?
          sudo nix store optimise || return $?
          ;;
        up)
          echo "[nixos up] Updating flake + rebuilding system + home-manager..."
          cd "$HOME/dots-files" || return 1
          nix flake update || return $?
          sudo nixos-rebuild switch --flake .#nixos || return $?
          home-manager switch --flake .#alex || return $?
          ;;
        "")
          echo "usage: nixos <gc|up>"
          return 1
          ;;
        *)
          echo "unknown nixos subcommand: $cmd"
          echo "usage: nixos <gc|up>"
          return 1
          ;;
      esac
    }

    # Auto-start local postgres when running psql (only for local sockets/localhost).
    psql() {
      local host="''${PGHOST:-}"
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

  home.sessionVariables = {
    SHELL = "${pkgs.zsh}/bin/zsh";
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    LIBVA_DRIVER_NAME = "iris";
  };

  # ===== Packages =====
  home.packages = with pkgs; [
    htop
    fastfetch
    vicinae
    whisper-cpp
    mpv
    slurp
    gsettings-desktop-schemas
    tree
    glib
    pywalfox-native
    flatpak
    obs-studio
    vlc
    inotify-tools
    libreoffice
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

  home.file.".local/bin/obsidian-git-sync" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      DIR="$HOME/notes/book"
      [ -d "$DIR" ] || exit 0
      cd "$DIR"
      ${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
      ${pkgs.git}/bin/git add -A
      if ! ${pkgs.git}/bin/git diff --cached --quiet; then
        ${pkgs.git}/bin/git commit -m "sync: $(date -u '+%Y-%m-%d %H:%M:%SZ')" || true
      fi
      if ${pkgs.git}/bin/git remote get-url origin >/dev/null 2>&1; then
        ${pkgs.git}/bin/git push -u origin HEAD || true
      fi
    '';
  };

  systemd.user.services.obsidian-git-sync = {
    Unit = {
      Description = "Auto-sync Obsidian vault to Git";
      After = [ "graphical-session.target" "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "%h/.local/bin/obsidian-git-sync";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.paths.obsidian-git-sync = {
    Unit = {
      Description = "Watch Obsidian vault for changes";
    };
    Path = {
      PathChanged = "%h/notes/book";
      PathModified = "%h/notes/book";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  home.activation.obsidianVaultInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -e
    dir="$HOME/notes/book"
    if [ ! -d "$dir/.git" ]; then
      mkdir -p "$dir"
      ${pkgs.git}/bin/git -C "$dir" init
      ${pkgs.git}/bin/git -C "$dir" checkout -B main
      ${pkgs.git}/bin/git -C "$dir" remote add origin git@github.com:NerdzzyDev/book.git || true
      ${pkgs.git}/bin/git -C "$dir" config user.name "alex"
      ${pkgs.git}/bin/git -C "$dir" config user.email "alex@local"
      touch "$dir/.gitkeep"
      ${pkgs.git}/bin/git -C "$dir" add -A
      ${pkgs.git}/bin/git -C "$dir" commit -m "init vault" || true
      ${pkgs.git}/bin/git -C "$dir" push -u origin main || true
    fi
  '';

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
