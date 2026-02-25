{ pkgs, ... }:

{
  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.05";

  programs.zsh.enable = true;
  # programs.ohMyZsh.enable = true;
  #programs.zsh.ohMyZsh.theme = "muse";
  #programs.zsh.ohMyZsh.plugins = [ "git" "sudo" "docker" "zsh-autosuggestions" "zsh-syntax-highlighting"];

  home.sessionVariables.SHELL = "${pkgs.zsh}/bin/zsh";

  # ===== Packages =====
  home.packages = with pkgs; [
    htop
    fastfetch
    nautilus
    mpv
    swaylock
    slurp
    gsettings-desktop-schemas
    tree
    vicinae
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


  # Автоматическая установка Flatpak приложений
      home.sessionVariables.FLATPAK_APPS = ''
        com.dec05eba.gpu_screen_recorder
        org.freedesktop.Platform.GL.default//23.08-extra
      '';

#  programs.vicinae = {
#        enable = true; # default: false
#    };

}

