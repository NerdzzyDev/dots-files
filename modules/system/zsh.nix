{ pkgs, ... }:

{
  programs.zsh = {
    enable = true;

    syntaxHighlighting.enable = true;
    autosuggestions.enable = true;

    ohMyZsh = {
      enable = true;
      theme = "muse";
      # `docker` plugin often slows shell startup due to heavy completion setup.
      plugins = [ "git" "sudo" ];
    };
  };
}
