{ lib, pkgs, ... }:

{
  ## ------------------------------------
  ## DEV PACKAGES
  ## ------------------------------------
  environment.systemPackages = with pkgs; [
    # Docker CLI
    docker
    docker-compose

    # Databases
    postgresql_16
    pgcli

    # Python
    (python3.withPackages (ps: with ps; [
      pip
      tkinter
      virtualenv
    ]))

    # Node.js / npm
    nodejs_20
    yarn
    pnpm

    # Go
    go

    # Utils
    gcc
    jq
    uv
    gh
  ];


  ## -----------------------------
  ## DOCKER (опционально)
  ## -----------------------------
  virtualisation.docker.enable = true;
  # Start dockerd on first use (socket activation), not on boot.
  virtualisation.docker.enableOnBoot = false;
  users.users.alex.extraGroups = [ "docker" ];


  ## -----------------------------
  ## POSTGRESQL (опционально)
  ## -----------------------------
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = "/var/lib/postgresql/16";
  
   initialScript = pkgs.writeText "init.sql" ''
     CREATE ROLE alex WITH LOGIN SUPERUSER;
      CREATE DATABASE dev OWNER alex;
    '';
  };

  # Keep PostgreSQL installed but do not auto-start at boot.
  systemd.services.postgresql.wantedBy = lib.mkForce [ ];
}
