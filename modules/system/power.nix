{ config, pkgs, ... }:

{
  # отключаем system76-scheduler (может мешать deep sleep)
  services.system76-scheduler.enable = false;

  # отключаем TLP, чтобы не конфликтовал с power-profiles-daemon
  services.tlp.enable = false;

  # включаем power-profiles-daemon (даст powerprofilesctl)
  services.power-profiles-daemon.enable = true;

  # полезные сервисы для ноута
  # Keep the tool installed, but don't auto-tune on every boot (it slows startup).
  powerManagement.powertop.enable = false;
  services.thermald.enable = true;
  services.upower.enable = true;
  services.acpid.enable = true;

  # пакеты (добавим power-profiles-daemon, чтобы был powerprofilesctl)
  environment.systemPackages = with pkgs; [
    powertop
    acpi
    upower
    power-profiles-daemon
  ];
}
