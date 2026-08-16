{ pkgs, pkgsUnstable, ... }:

{
  imports = [ ./self-check.nix ];

  wsl = {
    enable = true;
    wslConf.interop = {
      enabled = true;
      appendWindowsPath = false;
    };
  };

  networking.hostName = "nixos-wsl";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  environment.systemPackages = (with pkgs; [
    git
    jq
    kubectl
    kubernetes-helm
    openssh
  ]) ++ [
    pkgsUnstable.pulumi
  ];

  system.stateVersion = "26.05";
}
