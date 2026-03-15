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

  # Automatically switch power profiles on AC/Battery.
  services.udev.extraRules = ''
    ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set balanced"
    ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${pkgs.power-profiles-daemon}/bin/powerprofilesctl set power-saver"

    # Keep battery thresholds pinned to runtime mode (some firmware/tools override them).
    ACTION=="change", SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${pkgs.bash}/bin/bash -c 'echo 95 > /sys/class/power_supply/BAT0/charge_control_start_threshold; echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold'"
  '';

  # Prefer full charge for longer runtime (change if you want battery preservation).
  systemd.services.battery-charge-thresholds = {
    description = "Set battery charge thresholds";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 95 > /sys/class/power_supply/BAT0/charge_control_start_threshold; echo 100 > /sys/class/power_supply/BAT0/charge_control_end_threshold'";
      RemainAfterExit = true;
    };
  };

  # пакеты (добавим power-profiles-daemon, чтобы был powerprofilesctl)
  environment.systemPackages = with pkgs; [
    powertop
    acpi
    upower
    power-profiles-daemon
  ];
}
