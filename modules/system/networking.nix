{
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Moscow";

  i18n.defaultLocale = "en_US.UTF-8";

  networking.firewall.allowedTCPPorts = [ 3131 ];

}
