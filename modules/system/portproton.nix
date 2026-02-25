{ config, pkgs, ... }:

{
  # Включаем Vulkan
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages = with pkgs; [
    vulkan-tools            # vkcube, vulkaninfo
    mangohud                # overlay FPS
    goverlay                # GUI для настроек Proton/MangoHud
  ];

  # Steam + Proton
  programs.steam = {
    enable = true;

    # Это включает необходимые 32-битные библиотеки
    extraPackages = with pkgs; [
      proton-ge-custom
    ];

    # Либо можно указать Proton-GE напрямую
    protonPackages = with pkgs; [
      proton-ge-custom
    ];
  };

  # Опционально — GameMode (ускоряет запуск игр + CPU governor)
  programs.gamemode.enable = true;

  # Для некоторых игр нужные динамические библиотки
  hardware.pulseaudio.support32Bit = true;
}


