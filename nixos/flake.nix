{
  description = "DataWorkStation NixOS WSL developer environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/2605.7.2";
  };

  outputs =
    { nixpkgs, nixpkgs-unstable, nixos-wsl, ... }:
    {
      nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs.pkgsUnstable = import nixpkgs-unstable {
          system = "x86_64-linux";
        };
        modules = [
          nixos-wsl.nixosModules.default
          ./configuration.nix
          ./local.nix
        ];
      };
    };
}
