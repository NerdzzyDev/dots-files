{ pkgs, ... }:

let
  singBoxProfileCtl = pkgs.writeShellApplication {
    name = "sing-box-profilectl";
    runtimeInputs = [ pkgs.coreutils pkgs.jq ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      base_config="/etc/sing-box/config.json"
      state_file="/home/alex/.local/state/sing-box/profile"
      runtime_config="/run/sing-box/config.json"
      systemctl_bin="/run/current-system/sw/bin/systemctl"
      pkexec_bin="/run/current-system/sw/bin/pkexec"

      current_mode() {
        if [ -f "$state_file" ]; then
          tr -d '[:space:]' < "$state_file"
        else
          echo "proxy"
        fi
      }

      write_state() {
        local mode="$1"
        mkdir -p "$(dirname "$state_file")"
        printf '%s\n' "$mode" > "$state_file"
      }

      auth_systemctl() {
        if [ -x "$pkexec_bin" ]; then
          "$pkexec_bin" "$systemctl_bin" "$@"
        else
          sudo "$systemctl_bin" "$@"
        fi
      }

      generate_config() {
        local mode="''${1:-$(current_mode)}"
        mkdir -p /run/sing-box

        case "$mode" in
          proxy)
            cp "$base_config" "$runtime_config"
            ;;
          tun)
            jq '
              def tun_inbound:
                {
                  "type": "tun",
                  "tag": "tun-in",
                  "interface_name": "singbox0",
                  "address": ["172.18.0.1/30", "fdfe:dcba:9876::1/126"],
                  "mtu": 9000,
                  "auto_route": true,
                  "auto_redirect": true,
                  "strict_route": true,
                  "stack": "mixed"
                };

              .inbounds = (
                [tun_inbound]
                + (
                  .inbounds
                  | map(
                      if .type == "mixed" then
                        .set_system_proxy = false
                      else
                        .
                      end
                    )
                  | map(select(.type != "tun"))
                )
              )
              | .route.auto_detect_interface = true
              | .route.default_domain_resolver = {
                  "server": "dns-direct",
                  "strategy": "prefer_ipv4",
                  "rewrite_ttl": 60
                }
              | .route.final = "🌐 Anonymous Multi"
            ' "$base_config" > "$runtime_config"
            ;;
          off)
            cp "$base_config" "$runtime_config"
            ;;
          *)
            printf 'unknown profile: %s\n' "$mode" >&2
            exit 1
            ;;
        esac
      }

      apply_mode() {
        local mode="$1"

        case "$mode" in
          proxy|tun|off) ;;
          *)
            printf 'unknown profile: %s\n' "$mode" >&2
            exit 1
            ;;
        esac

        if [ "$mode" = "off" ]; then
          auth_systemctl stop sing-box
          return
        fi

        write_state "$mode"

        if "$systemctl_bin" is-active --quiet sing-box; then
          auth_systemctl restart sing-box
        else
          auth_systemctl start sing-box
        fi
      }

      status_json() {
        local mode active icon color tooltip text

        mode="$(current_mode)"
        if "$systemctl_bin" is-active --quiet sing-box; then
          active="yes"
        else
          active="no"
        fi

        case "$mode" in
          proxy)
            icon="shield"
            text="SS"
            color="secondary"
            tooltip="sing-box profile: SS"
            ;;
          tun)
            icon="shield-lock"
            text="TUN"
            color="primary"
            tooltip="sing-box profile: tun"
            ;;
          off)
            icon="shield-off"
            text="OFF"
            color="none"
            tooltip="sing-box stopped"
            ;;
          *)
            icon="shield"
            text="$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')"
            color="none"
            tooltip="sing-box profile: $mode"
            ;;
        esac

        if [ "$active" = "no" ]; then
          icon="shield-off"
          text="OFF"
          color="none"
          tooltip="sing-box stopped (profile: $mode)"
        fi

        jq -nc \
          --arg text "$text" \
          --arg icon "$icon" \
          --arg color "$color" \
          --arg tooltip "$tooltip" \
          --arg profile "$mode" \
          --arg active "$active" \
          '{text: $text, icon: $icon, color: $color, tooltip: $tooltip, profile: $profile, active: ($active == "yes")}'
      }

      case "''${1:-status}" in
        status)
          status_json
          ;;
        generate)
          generate_config "''${2:-}"
          ;;
        default)
          write_state proxy
          ;;
        set)
          apply_mode "''${2:?profile required}"
          ;;
        off)
          apply_mode off
          ;;
        proxy)
          apply_mode proxy
          ;;
        tun)
          apply_mode tun
          ;;
        *)
          printf 'usage: sing-box-profilectl {status|generate|default|set|off|proxy|tun}\n' >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ singBoxProfileCtl ];

  systemd.services.sing-box = {
    description = "sing-box service";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      RuntimeDirectory = "sing-box";
      ExecStartPre = "${singBoxProfileCtl}/bin/sing-box-profilectl generate";
      ExecStart = "${pkgs.sing-box}/bin/sing-box run -c /run/sing-box/config.json";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.sing-box-profile-default = {
    description = "Reset sing-box default profile on boot";
    wantedBy = [ "multi-user.target" ];
    before = [ "sing-box.service" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${singBoxProfileCtl}/bin/sing-box-profilectl default";
    };
  };

  users.users.sing-box = {
    isSystemUser = true;
    group = "sing-box";
  };

  users.groups.sing-box = {};
}
