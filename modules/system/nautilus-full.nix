{ config, pkgs, ... }:

{
  # Нужно для многих GNOME/GTK приложений (настройки, интеграции)
  programs.dconf.enable = true;

  # Автомонтирование флешек/дисков “как в нормальном десктопе”
  services.udisks2.enable = true;

  # GVFS: ftp/sftp/smb/dav/mtp + “Connect to Server…” в Nautilus
  services.gvfs.enable = true;

  # Политики/запросы прав (в wl-композиторах типа niri критично)
  security.polkit.enable = true;

  # Чтобы сохранялись пароли от FTP/SMB и т.п. (опционально, но “полный” опыт)
  services.gnome.gnome-keyring.enable = true;

  # Порталы (улучшает file chooser/интеграцию в Wayland)
  programs.niri.useNautilus = false;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome
    xdg-desktop-portal-wlr
  ];

  xdg.portal.wlr.enable = true;

  xdg.portal.config = {
    common = {
      default = [ "gtk" ];
    };

    niri = {
      "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
    };
  };

  environment.systemPackages = with pkgs; [
    nautilus

    # GVFS иногда требует сетевой TLS-бэкенд
    glib-networking

    # Архивы/контекстное меню “извлечь сюда”
    file-roller


    # Polkit-агент (должен быть запущен в сессии)
    lxqt.lxqt-policykit
  ];

  # Надёжно запускаем polkit-agent через systemd user (чтобы не зависеть от автозапуска niri)
  systemd.user.services.polkit-agent = {
    description = "Polkit authentication agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.lxqt.lxqt-policykit}/bin/lxqt-policykit-agent";
      Restart = "on-failure";
    };
  };

  # In niri sessions portal backends can start before the Wayland display env is
  # ready. That breaks screencast (OBS) or causes long xdg-desktop-portal timeouts.
  systemd.user.services.xdg-desktop-portal-gtk = {
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.xdg-desktop-portal-gnome = {
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.xdg-desktop-portal = {
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Force a clean portal restart after the graphical session is fully up.
  # This fixes OBS screencast sources missing right after login.
  systemd.user.services.xdg-desktop-portal-restart = {
    description = "Restart portals after graphical session is ready";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal-gtk xdg-desktop-portal-gnome xdg-desktop-portal";
    };
  };

  # Иногда полезно, чтобы окружение корректно подхватывалось в Wayland-сессии
  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "niri";
  };
}
