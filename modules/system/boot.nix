{ config, pkgs, ... }:

{
  # Отключаем systemd-boot, иначе будет конфликт
  boot.loader.systemd-boot.enable = false;

  boot.loader.efi.canTouchEfiVariables = true;

  boot.loader.grub = {
    enable = true;
    version = 2;
    efiSupport = true;

    # Не писать в MBR — только EFI
    device = "nodev";

    # Позволяет находить EndeavourOS / Arch
    useOSProber = true;
  };

  # os-prober как пакет (требуется для сканирования других ОС)
  environment.systemPackages = with pkgs; [
    os-prober
  ];
}


#{
#  boot.loader.systemd-boot.enable = true;
#  boot.loader.efi.canTouchEfiVariables = true;
#}
