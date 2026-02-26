{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  networking.networkmanager.dns = "systemd-resolved";
  networking.networkmanager.wifi.powersave = false;
  services.resolved.enable = true;
  # IPv6 is currently broken (no default route). Disable to avoid timeouts.
  networking.enableIPv6 = false;
  # Skip wait-online to speed up boot; use it only if you have strict ordering needs.
  systemd.services.NetworkManager-wait-online.enable = false;

  time.timeZone = "Europe/Moscow";

  i18n.defaultLocale = "en_US.UTF-8";

  networking.firewall.allowedTCPPorts = [ 3131 ];

}
