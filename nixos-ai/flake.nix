{
  description = "DataWorkStation restricted AI NixOS WSL environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/2605.7.2";
  };

  outputs =
    { nixpkgs, nixos-wsl, ... }:
    {
      nixosConfigurations.ai-workstation = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-wsl.nixosModules.default
          ./configuration.nix
          ./local.nix
        ];
      };
    };
}
