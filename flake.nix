{
  description = "stringju's NixOS dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    bongocat.url = "github:saatvik333/wayland-bongocat";
    omp.url = "github:can1357/oh-my-pi";
  };

  outputs = { self, nixpkgs, bongocat, omp, ... }:
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
        stringju-work = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/stringju-work/configuration.nix
            bongocat.nixosModules.default
            omp.nixosModules.default
          ];
        };
      };
    };
}
