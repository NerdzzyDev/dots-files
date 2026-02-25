{ pkgs, ... }:

{
  ## ------------------------------------
  ## DEV PACKAGES
  ## ------------------------------------
  environment.systemPackages = with pkgs; [
    # Docker CLI
    docker
    docker-compose

    # Databases
    postgresql
    pgcli

    # Python
    python3
    python3Packages.pip
    python3Packages.virtualenv

    # Node.js / npm
    nodejs_20
    yarn
    pnpm

    # Go
    go

    # Utils
    jq
  ];


  ## -----------------------------
  ## DOCKER (опционально)
  ## -----------------------------
  virtualisation.docker.enable = true;
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
}

