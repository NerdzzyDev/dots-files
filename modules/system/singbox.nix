{ pkgs, ... }:

{
  systemd.services.sing-box = {
    description = "sing-box service";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c /etc/sing-box/config.json";
      Restart = "on-failure";
    };
  };

  users.users.sing-box = {
    isSystemUser = true;
    group = "sing-box";
  };

  users.groups.sing-box = {};
}

