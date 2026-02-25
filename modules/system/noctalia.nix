{ inputs, noctalia, pkgs, ... }:

{
  imports = [
    noctalia.nixosModules.default
  ];
}
