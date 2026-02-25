{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    syntaxHighlighting.enable = true;
    autosuggestions.enable = true;

    ohMyZsh = {
      enable = true;
      theme = "muse";
      plugins = [ "git" "sudo" "docker" ];
    };
  };
}

