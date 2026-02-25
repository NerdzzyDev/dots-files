{ config, pkgs, ... }:

{
  # Любые общие настройки Home Manager для всех пользователей
  home.file.".bashrc".text = ''
    # Custom bashrc snippet
    export EDITOR=nvim
  '';
}

