{
  description = "stringju's NixOS dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    bongocat.url = "github:saatvik333/wayland-bongocat";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, bongocat, sops-nix, ... }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations = {
        thinkpad-t14-gen2 = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/thinkpad-t14-gen2/configuration.nix
            bongocat.nixosModules.default
          ];
        };
        stringju-work = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./hosts/stringju-work/configuration.nix
            bongocat.nixosModules.default
            sops-nix.nixosModules.sops
          ];
        };
      };
    };
}
