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
  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [
    xdg-desktop-portal-gtk
  ];

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

  # In niri sessions the GTK portal occasionally starts before the display env is
  # fully available and exits. Restarting avoids long xdg-desktop-portal timeouts.
  systemd.user.services.xdg-desktop-portal-gtk = {
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  systemd.user.services.xdg-desktop-portal = {
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = 2;
    };
  };

  # Иногда полезно, чтобы окружение корректно подхватывалось в Wayland-сессии
  environment.sessionVariables = {
    XDG_CURRENT_DESKTOP = "niri";
  };
}
