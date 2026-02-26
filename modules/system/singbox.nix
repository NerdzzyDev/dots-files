{ pkgs, ... }:

{
  systemd.services.sing-box = {
    description = "sing-box service";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c /etc/sing-box/config.json";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  users.users.sing-box = {
    isSystemUser = true;
    group = "sing-box";
  };

  users.groups.sing-box = {};
}
