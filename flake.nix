{
  description = "NixOS modular config with Home Manager & Noctalia";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    noctalia.url = "github:noctalia-dev/noctalia-shell";
    noctalia.inputs.nixpkgs.follows = "nixpkgs";
    vicinae.url = "github:vicinaehq/vicinae";
    zen-browser.url = "github:youwen5/zen-browser-flake";
    zen-browser.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, noctalia, vicinae, zen-browser, ... }:
  let
    system = "x86_64-linux";


    # Overlays: NUR + DaVinci overlay
    pkgs = import nixpkgs {
      inherit system;
      config = { allowUnfree = true; };
    };
  in
  {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      inherit system pkgs;
      specialArgs = { inherit home-manager noctalia; zenBrowser = zen-browser; };

      modules = [
        ./configuration.nix

        # System modules
        ./modules/system/boot.nix
        ./modules/system/networking.nix
        ./modules/system/bluetooth.nix
        ./modules/system/pipewire.nix
        ./modules/system/nix-ld-compat.nix
        ./modules/system/zsh.nix
        ./modules/system/niri.nix
        ./modules/system/singbox.nix
        ./modules/system/packages.nix
        ./modules/system/power.nix
        ./modules/system/vm.nix
        ./modules/system/dev.nix
        ./modules/system/nautilus-full.nix
        ./modules/system/meetily-build.nix
	

        # Optional profiles (keep disabled until needed)
        # ./modules/system/portproton.nix
        ./modules/system/transmission.nix
        

        # Home Manager system module
        home-manager.nixosModules.home-manager


#	{
#        environment.defaultPackages = with pkgs; [
#          (callPackage ./modules/system/davinci.nix { })
#        ];
#      }

      ];
      };

      

    # Home Manager для alex с Noctalia
    homeConfigurations.alex = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./home/alex.nix
        noctalia.homeModules.default
        vicinae.homeManagerModules.default
      ];
    };
  };
}
