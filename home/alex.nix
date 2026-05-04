{ lib, pkgs, ... }:

let
  gazeCorrectionCam = pkgs.writeShellApplication {
    name = "gaze-correction-cam";
    runtimeInputs = [
      pkgs.vicinae
      (pkgs.python3.withPackages (ps: with ps; [
        ps."face-recognition"
        ps."face-recognition-models"
        numpy
        ps."opencv-python"
        pillow
        tkinter
      ]))
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      python3 - "$@" <<'PY'
import argparse
import glob
import os
import subprocess
from pathlib import Path
import sys

import cv2
import face_recognition
import numpy as np
from PIL import Image, ImageTk
import tkinter as tk


LEFT_EYE = [36, 37, 38, 39, 40, 41]
RIGHT_EYE = [42, 43, 44, 45, 46, 47]


def clamp(value, low, high):
    return max(low, min(high, value))
def landmarks_to_box(landmarks, width, height, padding=0.35):
    xs = [p[0] for p in landmarks]
    ys = [p[1] for p in landmarks]
    span_x = max(xs) - min(xs)
    span_y = max(ys) - min(ys)
    x1 = int(max(0, min(xs) - padding * span_x))
    y1 = int(max(0, min(ys) - padding * span_y))
    x2 = int(min(width, max(xs) + padding * span_x))
    y2 = int(min(height, max(ys) + padding * span_y))
    return x1, y1, x2, y2


def pupil_center(crop):
    h, w = crop.shape[:2]
    x1 = int(w * 0.15)
    x2 = int(w * 0.85)
    y1 = int(h * 0.20)
    y2 = int(h * 0.80)

    roi = crop[y1:y2, x1:x2]
    gray = cv2.cvtColor(roi, cv2.COLOR_BGR2GRAY)
    gray = cv2.GaussianBlur(gray, (5, 5), 0)
    threshold = np.percentile(gray, 12)
    mask = gray <= threshold

    if int(mask.sum()) < 6:
        return w / 2.0, h / 2.0

    ys, xs = np.nonzero(mask)
    return float(xs.mean() + x1), float(ys.mean() + y1)


def warp_eye(frame, box, strength=0.85):
    x1, y1, x2, y2 = box
    if x2 <= x1 or y2 <= y1:
        return frame

    crop = frame[y1:y2, x1:x2].copy()
    h, w = crop.shape[:2]
    if h < 2 or w < 2:
        return frame

    pupil_x, pupil_y = pupil_center(crop)
    dx = (w / 2.0 - pupil_x) * strength
    dy = (h / 2.0 - pupil_y) * strength
    dx = clamp(dx, -0.35 * w, 0.35 * w)
    dy = clamp(dy, -0.28 * h, 0.28 * h)

    matrix = np.float32([[1.0, 0.0, dx], [0.0, 1.0, dy]])
    shifted = cv2.warpAffine(
        crop,
        matrix,
        (w, h),
        flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_REFLECT_101,
    )

    mask = np.zeros((h, w), dtype=np.uint8)
    center = (w // 2, h // 2)
    axes = (max(1, int(w * 0.42)), max(1, int(h * 0.30)))
    cv2.ellipse(mask, center, axes, 0, 0, 360, 255, -1)
    mask = cv2.GaussianBlur(mask, (0, 0), sigmaX=max(3.0, min(w, h) * 0.08))
    alpha = (mask.astype(np.float32) / 255.0)[..., None]

    frame[y1:y2, x1:x2] = (
        shifted.astype(np.float32) * alpha
        + crop.astype(np.float32) * (1.0 - alpha)
    ).astype(np.uint8)
    return frame


def camera_candidates():
    by_id = sorted(glob.glob("/dev/v4l/by-id/*"))
    if by_id:
        preferred = [p for p in by_id if p.endswith("video-index0")]
        return preferred or by_id
    return sorted(glob.glob("/dev/video*"))


def choose_camera(value):
    if value not in (None, "", "auto"):
        return value

    candidates = camera_candidates()
    if not candidates:
        return "0"

    preferred = [c for c in candidates if "usb" in os.path.basename(c).lower()]
    if preferred:
        return preferred[0]

    non_platform = [c for c in candidates if "platform" not in os.path.basename(c).lower()]
    if non_platform:
        return non_platform[0]

    return candidates[0]


def resolve_camera_device(value):
    camera = choose_camera(value)
    text = str(camera)

    if text.isdigit():
        return int(text)

    path = Path(text)
    if path.exists():
        real = path.resolve()
        if real.name.startswith("video") and real.name[5:].isdigit():
            return int(real.name[5:])
        return str(real)

    if text.startswith("/dev/video") and text[10:].isdigit():
        return int(text[10:])

    return text


def camera_label(entry):
    raw = Path(entry).name
    if "046d_0825" in raw:
        return "Logitech Webcam"
    if "SunplusIT_Inc_HD_Camera" in raw:
        return "Built-in HD Camera"
    if entry.startswith("/dev/v4l/by-id/"):
        return raw.replace("usb-", "").replace("-video-index0", "").replace("-video-index1", "").replace("_", " ")
    if entry.startswith("/dev/video"):
        return entry
    return entry


def list_camera_entries():
    entries = []
    seen = set()

    for candidate in camera_candidates():
        if candidate not in seen:
            seen.add(candidate)
            entries.append(candidate)

    return entries


def pick_camera_vicinae(entries):
    lines = [camera_label(entry) for entry in entries]
    proc = subprocess.run(
        [
            "vicinae",
            "dmenu",
            "--navigation-title",
            "Choose camera",
            "--section-title",
            "Available cameras ({count})",
            "--placeholder",
            "Type to filter cameras",
        ],
        input="\n".join(lines) + "\n",
        text=True,
        capture_output=True,
        check=False,
    )

    if proc.returncode != 0:
        return None

    selected = proc.stdout.strip()
    if not selected:
        return None

    for entry in entries:
        if camera_label(entry) == selected:
            return entry

    return None


def pick_camera_tty(entries):
    print("Choose camera:", file=sys.stderr)
    for idx, entry in enumerate(entries, start=1):
        print(f"{idx}. {camera_label(entry)}", file=sys.stderr)
    choice = input("Camera number: ").strip()
    if not choice.isdigit():
        return None
    index = int(choice) - 1
    if index < 0 or index >= len(entries):
        return None
    return entries[index]


def open_capture(source, width, height):
    if isinstance(source, int):
        index = source
    elif isinstance(source, str) and source.startswith("/dev/video") and source[10:].isdigit():
        index = int(source[10:])
    else:
        index = None

    attempts = []
    if index is not None:
        attempts.extend(
            [
                (index, cv2.CAP_V4L2, cv2.VideoWriter_fourcc(*"YUYV")),
                (index, cv2.CAP_V4L2, cv2.VideoWriter_fourcc(*"MJPG")),
                (index, cv2.CAP_ANY),
            ]
        )
    else:
        attempts.append((source, cv2.CAP_ANY))

    for attempt in attempts:
        if len(attempt) == 3:
            device, backend, fourcc = attempt
        else:
            device, backend = attempt
            fourcc = None

        cap = cv2.VideoCapture(device, backend)
        if fourcc is not None:
            cap.set(cv2.CAP_PROP_FOURCC, fourcc)
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, width)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, height)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        ok, frame = cap.read()
        if ok and frame is not None and frame.size > 0:
            return cap

        cap.release()

    return None


def main():
    parser = argparse.ArgumentParser(description="Local gaze-correction preview for OBS.")
    parser.add_argument(
        "--camera",
        default="auto",
        help="Camera index or device path. Use 'auto' to prefer external cameras.",
    )
    parser.add_argument(
        "--pick-camera",
        action="store_true",
        help="Pick a camera from a list using vicinae, then start the preview.",
    )
    parser.add_argument(
        "--list-cameras",
        action="store_true",
        help="Print detected camera candidates and exit.",
    )
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument(
        "--detect-every",
        type=int,
        default=1,
        help="Run face detection every N frames.",
    )
    parser.add_argument(
        "--compare",
        action="store_true",
        help="Show raw and corrected frames side by side.",
    )
    parser.add_argument(
        "--raw",
        action="store_true",
        help="Show the camera stream without gaze correction.",
    )
    parser.add_argument("--mirror", action="store_true", default=True)
    parser.add_argument("--no-mirror", dest="mirror", action="store_false")
    args = parser.parse_args()

    if args.list_cameras:
        for candidate in camera_candidates():
            print(camera_label(candidate))
        return 0

    entries = list_camera_entries()
    if not entries:
        print("No cameras found", file=sys.stderr)
        return 1

    if args.pick_camera:
        print("Available cameras:", file=sys.stderr)
        for idx, entry in enumerate(entries, start=1):
            print(f"{idx}. {camera_label(entry)}", file=sys.stderr)
        camera = pick_camera_vicinae(entries)
        if camera is None:
            camera = pick_camera_tty(entries)
        if camera is None:
            return 1
    else:
        camera = resolve_camera_device(args.camera)

    camera = resolve_camera_device(camera)

    cap = open_capture(camera, args.width, args.height)
    if cap is None or not cap.isOpened():
        print(f"Could not open camera {camera}", file=sys.stderr)
        return 1

    print(f"Using camera: {camera}", file=sys.stderr)

    app = tk.Tk()
    app.title("Gaze Correction Preview")
    app.configure(bg="black")

    image_label = tk.Label(app, bg="black")
    image_label.pack(fill="both", expand=True)
    status = tk.Label(
        app,
        text="q = quit",
        fg="white",
        bg="black",
        anchor="w",
        padx=12,
        pady=6,
    )
    status.pack(fill="x")

    state = {"photo": None}
    frame_count = 0
    last_boxes = {"left": None, "right": None}
    detect_every = max(1, args.detect_every)

    def update_frame():
        nonlocal frame_count, last_boxes
        if not app.winfo_exists():
            return

        ok, frame = cap.read()
        if not ok:
            app.after(10, update_frame)
            return

        if args.mirror:
            frame = cv2.flip(frame, 1)

        raw_frame = frame.copy()
        corrected_frame = frame

        if not args.raw:
            frame_count += 1
            do_detect = frame_count % detect_every == 1 or (last_boxes["left"] is None and last_boxes["right"] is None)
            if do_detect:
                small = cv2.resize(frame, None, fx=0.25, fy=0.25, interpolation=cv2.INTER_AREA)
                rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
                detected = face_recognition.face_landmarks(rgb)

                if detected:
                    width = frame.shape[1]
                    height = frame.shape[0]
                    face = detected[0]

                    if "left_eye" in face:
                        left = [(x * 4, y * 4) for x, y in face["left_eye"]]
                        last_boxes["left"] = landmarks_to_box(left, width, height)

                    if "right_eye" in face:
                        right = [(x * 4, y * 4) for x, y in face["right_eye"]]
                        last_boxes["right"] = landmarks_to_box(right, width, height)

            if last_boxes["left"] is not None:
                corrected_frame = warp_eye(corrected_frame, last_boxes["left"])

            if last_boxes["right"] is not None:
                corrected_frame = warp_eye(corrected_frame, last_boxes["right"])

        if args.compare:
            left_view = cv2.resize(raw_frame, (640, 360), interpolation=cv2.INTER_AREA)
            right_view = cv2.resize(corrected_frame, (640, 360), interpolation=cv2.INTER_AREA)
            cv2.putText(left_view, "RAW", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (240, 240, 240), 2, cv2.LINE_AA)
            cv2.putText(right_view, "CORRECTED", (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, (240, 240, 240), 2, cv2.LINE_AA)
            display = cv2.hconcat([left_view, right_view])
        else:
            display = corrected_frame if not args.raw else raw_frame

        display = cv2.cvtColor(display, cv2.COLOR_BGR2RGB)
        image = Image.fromarray(display)
        state["photo"] = ImageTk.PhotoImage(image=image)
        image_label.configure(image=state["photo"])
        app.after(1, update_frame)

    def on_close():
        cap.release()
        app.destroy()

    app.protocol("WM_DELETE_WINDOW", on_close)
    app.bind("q", lambda event: on_close())
    app.after(0, update_frame)
    app.mainloop()

    cap.release()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
    '';
  };
in

{
  home.username = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion = "25.05";

  programs.zsh.enable = true;
  # We run compinit manually with cached mode (-C) for faster prompt readiness.
  programs.zsh.enableCompletion = false;
  programs.zsh.shellAliases = {
    uinit = "uv init";
    uvenv = "uv venv";
    uadd = "uv add";
    urm = "uv remove";
    usync = "uv sync";
    urun = "uv run";
    ulock = "uv lock";
    upy = "uv run python";
    upym = "uv run python -m";

    gazeobs = "gaze-correction-cam --pick-camera";
    gazeobs-auto = "gaze-correction-cam --camera auto";
    gazeobs-logitech = "gaze-correction-cam --camera /dev/v4l/by-id/usb-046d_0825_80139B50-video-index0";
    gazeobs-builtin = "gaze-correction-cam --camera /dev/v4l/by-id/usb-SunplusIT_Inc_HD_Camera-video-index0";
    gazeobs-raw = "gaze-correction-cam --pick-camera --raw";
    gazeobs-compare = "gaze-correction-cam --pick-camera --compare";

    sbstart = "sudo systemctl start sing-box";
    sbstop = "sudo systemctl stop sing-box";
    sbrestart = "sudo systemctl restart sing-box";
    sbstatus = "sing-box-profilectl status";
    sbproxy = "sing-box-profilectl proxy";
    sbtun = "sing-box-profilectl tun";
    sboff = "sing-box-profilectl off";

    dockstart = "sudo systemctl start docker";
    dockstop = "sudo systemctl stop docker";
    dockstatus = "systemctl status docker";

    pgstart = "sudo systemctl start postgresql";
    pgstop = "sudo systemctl stop postgresql";
    pgstatus = "systemctl status postgresql";

    vmstart = "sudo systemctl start libvirtd";
    vmstop = "sudo systemctl stop libvirtd";
    vmstatus = "systemctl status libvirtd";

    codex-proxy = "ALL_PROXY=socks5h://127.0.0.1:2080 codex";

    ppsave = "powerprofilesctl set power-saver";
    ppbal = "powerprofilesctl set balanced";
    ppperf = "powerprofilesctl set performance";
  };
  programs.zsh.initContent = ''
    mkdir -p "$HOME/.cache/zsh"
    autoload -U compinit
    compinit -C -d "$HOME/.cache/zsh/zcompdump-$ZSH_VERSION"
    eval "$(direnv hook zsh)"

    _nix_proxy_port_open() {
      ${pkgs.python3}/bin/python3 - <<'PY'
import socket
import sys

try:
    conn = socket.create_connection(("127.0.0.1", 2080), timeout=0.5)
    conn.close()
except OSError:
    sys.exit(1)
PY
    }

    uvactivate() {
      if [[ -f .venv/bin/activate ]]; then
        # shellcheck disable=SC1091
        source .venv/bin/activate
      else
        echo "No .venv found in $(pwd)" >&2
        return 1
      fi
    }

    uvwork() {
      uv sync "$@" || return $?
      uvactivate
    }

    _nix_refresh_daemon_proxy() {
      if _nix_proxy_port_open; then
        echo "[nix] proxy is reachable, refreshing nix-daemon env"
      else
        echo "[nix] proxy is unreachable, refreshing nix-daemon for direct mode"
      fi

      sudo systemctl restart nix-daemon >/dev/null 2>&1 || true
    }

    nsw() {
      _nix_refresh_daemon_proxy
      sudo nixos-rebuild switch --flake "$HOME/dots-files#nixos" || return $?
    }

    hmsw() {
      _nix_refresh_daemon_proxy
      home-manager switch --flake "$HOME/dots-files#alex" || return $?
    }

    nixos() {
      local cmd="$1"
      shift || true

      case "$cmd" in
        gc)
          echo "[nixos gc] Cleaning user + system generations, store GC, optimize store..."
          nix-collect-garbage -d || return $?
          sudo nix-collect-garbage -d || return $?
          home-manager expire-generations "-14 days" || true
          sudo nix store gc || return $?
          sudo nix store optimise || return $?
          ;;
        up)
          echo "[nixos up] Updating flake + rebuilding system + home-manager..."
          cd "$HOME/dots-files" || return 1
          nix flake update || return $?
          _nix_refresh_daemon_proxy || return $?
          sudo nixos-rebuild switch --flake .#nixos || return $?
          home-manager switch --flake .#alex || return $?
          ;;
        "")
          echo "usage: nixos <gc|up>"
          return 1
          ;;
        *)
          echo "unknown nixos subcommand: $cmd"
          echo "usage: nixos <gc|up>"
          return 1
          ;;
      esac
    }

    # Auto-start local postgres when running psql (only for local sockets/localhost).
    psql() {
      local host="''${PGHOST:-}"
      if [ -z "$host" ] || [ "$host" = "localhost" ] || [[ "$host" = /* ]]; then
        if ! systemctl is-active --quiet postgresql 2>/dev/null; then
          sudo systemctl start postgresql >/dev/null 2>&1 || true
        fi
      fi
      command psql "$@"
    }

    # Start transmission daemon on GUI open.
    transmission-gtk() {
      if ! systemctl is-active --quiet transmission 2>/dev/null; then
        sudo systemctl start transmission >/dev/null 2>&1 || true
      fi
      command transmission-gtk "$@"
    }

    # Start libvirtd when launching virt-manager.
    virt-manager() {
      if ! systemctl is-active --quiet libvirtd 2>/dev/null; then
        sudo systemctl start libvirtd >/dev/null 2>&1 || true
      fi
      command virt-manager "$@"
    }

  '';
  # programs.ohMyZsh.enable = true;
  #programs.zsh.ohMyZsh.theme = "muse";
  #programs.zsh.ohMyZsh.plugins = [ "git" "sudo" "docker" "zsh-autosuggestions" "zsh-syntax-highlighting"];

  home.sessionVariables = {
    SHELL = "${pkgs.zsh}/bin/zsh";
    MOZ_ENABLE_WAYLAND = "1";
    MOZ_DISABLE_RDD_SANDBOX = "1";
    LIBVA_DRIVER_NAME = "iris";
    UV_PYTHON_PREFERENCE = "system";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # ===== Packages =====
  home.packages = with pkgs; [
    htop
    fastfetch
    vicinae
    whisper-cpp
    mpv
    slurp
    gsettings-desktop-schemas
    tree
    glib
    pywalfox-native
    flatpak
    obs-studio
    gazeCorrectionCam
    vlc
    wl-mirror
    inotify-tools
    libreoffice
    wineWow64Packages.full
    p7zip
    file
    grim
    anydesk
    mcp-nixos
  ];

  home.file.".config/fastfetch/config.jsonc".text = ''
    // Fastfetch config
    {
      "logo": {
        "type": "auto",
        "padding": {
          "top": 1
        }
      },
      "display": {
        "separator": "  ",
        "color": "blue"
      },
      "modules": [
        { "type": "title", "color": "blue" },
        { "type": "separator" },
        { "type": "os", "color": "cyan" },
        { "type": "host", "color": "cyan" },
        { "type": "kernel", "color": "cyan" },
        { "type": "uptime", "color": "cyan" },
        { "type": "packages", "color": "cyan" },
        { "type": "shell", "color": "cyan" },
        { "type": "de", "color": "cyan" },
        { "type": "wm", "color": "cyan" },
        { "type": "terminal", "color": "cyan" },
        { "type": "theme", "color": "magenta" },
        { "type": "icons", "color": "magenta" },
        { "type": "font", "color": "magenta" },
        { "type": "cursor", "color": "magenta" },
        { "type": "cpu", "color": "green" },
        { "type": "gpu", "color": "green" },
        { "type": "memory", "color": "green" },
        { "type": "disk", "color": "green" },
        { "type": "battery", "color": "yellow" },
        { "type": "localip", "color": "yellow" },
        { "type": "locale", "color": "yellow" },
        { "type": "break" },
        { "type": "colors" }
      ]
    }
  '';

  # ===== Noctalia =====
  programs.noctalia-shell.enable = true;

  home.file.".config/gtk-3.0/settings.ini" = {
    force = true;
    text = ''
    [Settings]
    gtk-theme-name=Adwaita-dark
    gtk-application-prefer-dark-theme=1
    '';
  };

  home.file.".config/gtk-4.0/settings.ini" = {
    force = true;
    text = ''
    [Settings]
    gtk-theme-name=Adwaita-dark
    gtk-application-prefer-dark-theme=1
    '';
  };

  home.file.".config/noctalia/plugins/singbox-switcher/manifest.json".text = ''
    {
      "id": "singbox-switcher",
      "name": "Sing-box Switcher",
      "version": "1.0.0",
      "author": "alex",
      "description": "Popup bar widget for switching sing-box profiles.",
      "entryPoints": {
        "barWidget": "BarWidget.qml"
      },
      "metadata": {
        "defaultSettings": {}
      }
    }
  '';

  home.file.".config/noctalia/plugins/singbox-switcher/BarWidget.qml".text = ''
    import QtQuick
    import Quickshell
    import Quickshell.Io
    import qs.Commons
    import qs.Modules.Bar.Extras
    import qs.Services.UI
    import qs.Widgets

    Item {
      id: root

      property ShellScreen screen
      property string widgetId: ""
      property string section: ""
      property int sectionWidgetIndex: -1
      property int sectionWidgetsCount: -1

      property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] ?? {}
      readonly property string screenName: screen ? screen.name : ""
      property var widgetSettings: {
        if (section && sectionWidgetIndex >= 0 && screenName) {
          var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
          if (widgets && sectionWidgetIndex < widgets.length) {
            return widgets[sectionWidgetIndex];
          }
        }
        return {};
      }

      readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
      readonly property bool isVerticalBar: barPosition === "left" || barPosition === "right"

      readonly property string profileCtl: "/run/current-system/sw/bin/sing-box-profilectl"
      property string currentProfile: "proxy"
      property bool isActive: true
      property string displayText: "SS"
      property string displayIcon: "shield"
      property string displayTooltip: "sing-box profile: SS"
      property color displayColor: Color.mSecondary

      implicitWidth: pill.width
      implicitHeight: pill.height

      function _applyStatus(payloadText) {
        try {
          var data = JSON.parse(payloadText || "{}");
          currentProfile = data.profile || "proxy";
          isActive = data.active !== undefined ? !!data.active : true;
          displayText = data.text || "SS";
          displayIcon = data.icon || "shield";
          displayTooltip = data.tooltip || "sing-box profile: SS";

          switch (data.color || "secondary") {
          case "primary":
            displayColor = Color.mPrimary;
            break;
          case "secondary":
            displayColor = Color.mSecondary;
            break;
          case "none":
          default:
            displayColor = Color.mOnSurface;
            break;
          }
        } catch (e) {
          Logger.e("SingBoxSwitcher", "Failed to parse sing-box status:", e.message);
        }
      }

      function refreshStatus() {
        if (!statusProcess.running) {
          statusProcess.running = true;
        }
      }

      function setMode(mode) {
        Quickshell.execDetached([profileCtl, mode]);
        refreshDelay.restart();
      }

      Component.onCompleted: refreshStatus()

      Timer {
        id: refreshDelay
        interval: 300
        repeat: false
        onTriggered: refreshStatus()
      }

      Timer {
        id: pollTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: refreshStatus()
      }

      Process {
        id: statusProcess
        command: [root.profileCtl, "status"]
        stdout: StdioCollector {}
        running: false
        onExited: function (exitCode) {
          if (exitCode === 0) {
            root._applyStatus(String(statusProcess.stdout.text || ""));
          }
        }
      }

      readonly property var contextModel: [
        {
          "label": "SS",
          "action": "proxy",
          "icon": currentProfile === "proxy" ? "check" : "shield"
        },
        {
          "label": "TUN",
          "action": "tun",
          "icon": currentProfile === "tun" ? "check" : "shield-lock"
        },
        {
          "label": "off",
          "action": "off",
          "icon": currentProfile === "off" || !isActive ? "check" : "shield-off"
        },
        {
          "label": I18n.tr("actions.widget-settings"),
          "action": "widget-settings",
          "icon": "settings"
        }
      ]

      NPopupContextMenu {
        id: contextMenu
        model: root.contextModel

        onTriggered: action => {
                       contextMenu.close();
                       PanelService.closeContextMenu(screen);

                       if (action === "widget-settings") {
                         BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
                         return;
                       }

                       if (action === "proxy" || action === "tun" || action === "off") {
                         root.setMode(action);
                       }
                     }
      }

      BarPill {
        id: pill

        screen: root.screen
        oppositeDirection: BarService.getPillDirection(root)
        icon: displayIcon
        text: displayText
        tooltipText: displayTooltip + "\nClick to choose SS, TUN, or off."
        autoHide: false
        forceOpen: false
        forceClose: false
        customTextIconColor: displayColor

        onClicked: {
          PanelService.showContextMenu(contextMenu, pill, screen);
        }

        onRightClicked: {
          BarService.openWidgetSettings(screen, section, sectionWidgetIndex, widgetId, widgetSettings);
        }
      }
    }
  '';

  systemd.user.services.vicinae = {
  Unit = {
    Description = "Vicinae Launcher Daemon";
    After = [ "graphical-session.target" ];
    PartOf = [ "graphical-session.target" ];
  };
  Service = {
    ExecStart = "${pkgs.vicinae}/bin/vicinae server";
    Restart = "always";
    RestartSec = 5;
    KillMode = "process";
  };
  Install = {
    WantedBy = [ "graphical-session.target" ];
  };
 };

  home.file.".local/bin/obsidian-git-sync" = {
    executable = true;
    text = ''
#!/usr/bin/env bash
set -euo pipefail
DIR="$HOME/notes/book"
[ -d "$DIR" ] || exit 0
cd "$DIR"
${pkgs.git}/bin/git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
${pkgs.git}/bin/git add -A
if ! ${pkgs.git}/bin/git diff --cached --quiet; then
  ${pkgs.git}/bin/git commit -m "sync: $(date -u '+%Y-%m-%d %H:%M:%SZ')" || true
fi
if ${pkgs.git}/bin/git remote get-url origin >/dev/null 2>&1; then
  ${pkgs.git}/bin/git push -u origin HEAD || true
fi
'';
  };

  home.file.".local/bin/niri-toggle-wl-mirror" = {
    executable = true;
    text = ''
#!/usr/bin/env bash
set -euo pipefail

if pgrep -x wl-mirror >/dev/null 2>&1; then
  pkill -x wl-mirror
  exit 0
fi

output="$(niri msg --json focused-output | ${pkgs.jq}/bin/jq -r '.name')"
exec ${pkgs.wl-mirror}/bin/wl-mirror "$output"
'';
  };

  home.file.".local/bin/niri-presentation-preview" = {
    executable = true;
    text = ''
#!/usr/bin/env bash
set -euo pipefail

title="Presentation Preview"

if pgrep -af "${pkgs.wl-mirror}/bin/wl-mirror .*--title ''${title}.* Virtual-1" >/dev/null 2>&1; then
  pkill -f "${pkgs.wl-mirror}/bin/wl-mirror .*--title ''${title}.* Virtual-1"
  exit 0
fi

niri msg output Virtual-1 mode 1920x1080@60.000 >/dev/null 2>&1 || true
exec ${pkgs.wl-mirror}/bin/wl-mirror --title "''${title}" Virtual-1
'';
  };

  home.file.".local/bin/niri-refresh-portals" = {
    executable = true;
    text = ''
#!/usr/bin/env bash
set -euo pipefail

sleep 3

export XDG_CURRENT_DESKTOP=niri

${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP || true
${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP || true

${pkgs.systemd}/bin/systemctl --user restart \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-wlr || true
'';
  };

  systemd.user.services.obsidian-git-sync = {
    Unit = {
      Description = "Auto-sync Obsidian vault to Git";
      After = [ "graphical-session.target" "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "%h/.local/bin/obsidian-git-sync";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.paths.obsidian-git-sync = {
    Unit = {
      Description = "Watch Obsidian vault for changes";
    };
    Path = {
      PathChanged = "%h/notes/book";
      PathModified = "%h/notes/book";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  home.activation.obsidianVaultInit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -e
    dir="$HOME/notes/book"
    if [ ! -d "$dir/.git" ]; then
      mkdir -p "$dir"
      ${pkgs.git}/bin/git -C "$dir" init
      ${pkgs.git}/bin/git -C "$dir" checkout -B main
      ${pkgs.git}/bin/git -C "$dir" remote add origin git@github.com:NerdzzyDev/book.git || true
      ${pkgs.git}/bin/git -C "$dir" config user.name "alex"
      ${pkgs.git}/bin/git -C "$dir" config user.email "alex@local"
      touch "$dir/.gitkeep"
      ${pkgs.git}/bin/git -C "$dir" add -A
      ${pkgs.git}/bin/git -C "$dir" commit -m "init vault" || true
      ${pkgs.git}/bin/git -C "$dir" push -u origin main || true
    fi
  '';

  home.activation.niriPresentationWorkflow = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -e
    cfg="$HOME/.config/niri/config.kdl"
    if [ ! -f "$cfg" ]; then
      exit 0
    fi

    ${pkgs.python3}/bin/python3 - <<'PY'
from pathlib import Path
import re
import sys

path = Path.home() / ".config/niri/config.kdl"
text = path.read_text()

replacement = """    // Niri Dynamic Cast (managed)
    Ctrl+Alt+8 hotkey-overlay-title="Presentation: workspace 9" { focus-workspace 9; }
    Ctrl+Alt+Shift+8 hotkey-overlay-title="Presentation: send window to workspace 9" { move-window-to-workspace 9; }
    Ctrl+Alt+9 hotkey-overlay-title="Dynamic Cast: focused window" { set-dynamic-cast-window; }
    Ctrl+Alt+F hotkey-overlay-title="Presentation: windowed fullscreen" { toggle-windowed-fullscreen; }
    Ctrl+Alt+0 hotkey-overlay-title="Presentation: cast focused monitor with shell" { set-dynamic-cast-monitor; }
    Ctrl+Alt+M hotkey-overlay-title="Presentation: toggle wl-mirror window" { spawn-sh "~/.local/bin/niri-toggle-wl-mirror"; }
    Ctrl+Alt+P allow-inhibiting=false hotkey-overlay-title="Presentation: preview Virtual-1 in 1080p" { spawn-sh "~/.local/bin/niri-presentation-preview"; }
    Ctrl+Left allow-inhibiting=false hotkey-overlay-title="Presentation: focus Virtual-1" { focus-monitor "Virtual-1"; }
    Ctrl+Right allow-inhibiting=false hotkey-overlay-title="Presentation: focus laptop monitor" { focus-monitor "eDP-1"; }
    Ctrl+Alt+Shift+Left allow-inhibiting=false hotkey-overlay-title="Presentation: move window to laptop monitor" { move-window-to-monitor "eDP-1"; }
    Ctrl+Alt+Shift+Right allow-inhibiting=false hotkey-overlay-title="Presentation: move window to Virtual-1" { move-window-to-monitor "Virtual-1"; }
    Ctrl+Alt+Minus hotkey-overlay-title="Dynamic Cast: clear target" { clear-dynamic-cast-target; }
    // End Niri Dynamic Cast"""

pattern = re.compile(
    r"    // Niri Dynamic Cast \(managed\)\n.*?    // End Niri Dynamic Cast",
    re.S,
)

updated, count = pattern.subn(replacement, text, count=1)
if count == 0:
    sys.exit("Failed to find the managed Niri Dynamic Cast block in ~/.config/niri/config.kdl")

if updated != text:
    path.write_text(updated)
PY
  '';

  home.activation.niriPortalRefresh = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -e
    cfg="$HOME/.config/niri/config.kdl"
    if [ ! -f "$cfg" ]; then
      exit 0
    fi

    ${pkgs.python3}/bin/python3 - <<'PY'
from pathlib import Path

path = Path.home() / ".config/niri/config.kdl"
text = path.read_text()

marker = 'spawn-at-startup "noctalia-shell"\n'
addition = marker + 'spawn-sh-at-startup "~/.local/bin/niri-refresh-portals"\n'

if 'spawn-sh-at-startup "~/.local/bin/niri-refresh-portals"' not in text and marker in text:
    text = text.replace(marker, addition, 1)
    path.write_text(text)
PY
  '';

  home.activation.noctaliaSingBoxWidget = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -e
    cfg="$HOME/.config/noctalia/settings.json"
    plugins_cfg="$HOME/.config/noctalia/plugins.json"

    if [ ! -f "$cfg" ]; then
      noctalia_bin="$(readlink -f "$(command -v noctalia-shell || true)" 2>/dev/null || true)"
      if [ -z "$noctalia_bin" ]; then
        exit 0
      fi

      shell_dir="$(dirname "$(dirname "$noctalia_bin")")/share/noctalia-shell"
      if [ ! -f "$shell_dir/Assets/settings-default.json" ]; then
        exit 0
      fi

      mkdir -p "$(dirname "$cfg")"
      cp "$shell_dir/Assets/settings-default.json" "$cfg"
    fi

    ${pkgs.python3}/bin/python3 - <<'PY'
from pathlib import Path
import json
import sys

path = Path.home() / ".config" / "noctalia" / "settings.json"
plugins_path = Path.home() / ".config" / "noctalia" / "plugins.json"

def load_json(path, default):
    if not path.exists():
        return default
    try:
        return json.loads(path.read_text())
    except Exception:
        return default

if not path.exists():
    sys.exit(0)

data = load_json(path, {})
bar = data.setdefault("bar", {})
widgets = bar.setdefault("widgets", {})
right = widgets.setdefault("right", [])

widget = {
    "id": "plugin:singbox-switcher"
}

def is_target(entry):
    return (
        entry.get("id") == "plugin:singbox-switcher"
        or (
            entry.get("id") == "CustomButton"
            and entry.get("ipcIdentifier") == "sing-box-ss"
        )
    )

for index, entry in enumerate(right):
    if is_target(entry):
        right[index] = widget
        break
else:
    insert_at = next((i for i, entry in enumerate(right) if entry.get("id") == "ControlCenter"), len(right))
    right.insert(insert_at, widget)

path.write_text(json.dumps(data, indent=2) + "\n")

plugins = load_json(plugins_path, {
    "version": 2,
    "states": {},
    "sources": []
})
states = plugins.setdefault("states", {})
state = states.setdefault("singbox-switcher", {})
state["enabled"] = True
plugins["version"] = 2
plugins_path.parent.mkdir(parents=True, exist_ok=True)
plugins_path.write_text(json.dumps(plugins, indent=2) + "\n")
PY
  '';

  home.file.".config/flatpak/remotes.d/flathub.flatpakrepo".text = ''
        [Remote "flathub"]
        Url=https://flathub.org/repo/flathub.flatpakrepo
        Enabled=true
      '';

  # Disable unwanted autostarts
  home.file.".config/autostart/Pluely.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Pluely
    Hidden=true
  '';
  home.file.".config/autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';


  # Автоматическая установка Flatpak приложений
      home.sessionVariables.FLATPAK_APPS = ''
        com.dec05eba.gpu_screen_recorder
        org.freedesktop.Platform.GL.default//23.08-extra
      '';

#  programs.vicinae = {
#        enable = true; # default: false
#    };

}
