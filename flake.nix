{
  description = "stringju's NixOS dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        thinkpad-t14-gen2 = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/thinkpad-t14-gen2/configuration.nix
          ];
        };
      };
    };
}
