{ pkgs, ... }:

let
  sourceManifest = pkgs.writeText "dataworkstation-ai-nixos-source-manifest" ''
    ${builtins.hashFile "sha256" ./flake.nix}  /etc/nixos/flake.nix
    ${builtins.hashFile "sha256" ./flake.lock}  /etc/nixos/flake.lock
    ${builtins.hashFile "sha256" ./configuration.nix}  /etc/nixos/configuration.nix
    ${builtins.hashFile "sha256" ./local.nix}  /etc/nixos/local.nix
    ${builtins.hashFile "sha256" ./self-check.nix}  /etc/nixos/self-check.nix
    ${builtins.hashFile "sha256" ./opencode-profile.json}  /etc/nixos/opencode-profile.json
  '';

  selfCheck = pkgs.writeShellApplication {
    name = "ai-workstation-self-check";
    runtimeInputs = with pkgs; [ coreutils gnugrep jq nix ];
    text = ''
      json=false
      case "''${1-}" in "") ;; --json) json=true ;; *) exit 64 ;; esac
      status=compliant
      exit_code=0
      detail="AI generation, source, commands, store, and WSL boundary are verified."
      StoreIntegrity=verified
      SourceIntegrity=matched
      CommandIntegrity=verified
      BoundaryIntegrity=verified
      active_system="$(readlink -f /run/current-system)"
      target_system=""

      if ! nix store verify --all --no-trust >/dev/null 2>&1; then
        StoreIntegrity=failed; status=altered; exit_code=2; detail="The complete Nix store failed verification."
      fi
      if ! sha256sum --check --status /etc/dataworkstation/ai-nixos-source-manifest; then
        SourceIntegrity=changed; [ "$exit_code" -eq 2 ] || exit_code=1; status=drifted; detail="Deployed AI Nix sources changed."
      fi
      for command_name in opencode opencode-sandbox ai-workstation-self-check; do
        resolved="$(readlink -f "$(command -v "$command_name" 2>/dev/null || true)" 2>/dev/null || true)"
        case "$resolved" in /nix/store/*) ;; *) CommandIntegrity=failed; status=altered; exit_code=2; detail="Managed command provenance failed: $command_name" ;; esac
      done
      if ! grep -A4 -E '^\[interop\]' /etc/wsl.conf | grep -Eq '^enabled[[:space:]]*=[[:space:]]*false' ||
         ! grep -A4 -E '^\[interop\]' /etc/wsl.conf | grep -Eq '^appendWindowsPath[[:space:]]*=[[:space:]]*false' ||
         ! grep -A4 -E '^\[automount\]' /etc/wsl.conf | grep -Eq '^enabled[[:space:]]*=[[:space:]]*false' ||
         findmnt -rn -o TARGET | grep -Eq '^/mnt/(c|d|wsl)(/|$)'; then
        BoundaryIntegrity=failed; status=altered; exit_code=2; detail="The restricted WSL boundary failed."
      fi
      if target_system="$(nix eval --raw /etc/nixos#nixosConfigurations.ai-workstation.config.system.build.toplevel.outPath 2>/dev/null)"; then
        if [ "$status" = compliant ] && [ "$active_system" != "$target_system" ]; then status=drifted; exit_code=1; detail="The evaluated AI generation is not active."; fi
      else
        [ "$exit_code" -eq 2 ] || exit_code=1; status=drifted; detail="The AI flake cannot be evaluated."
      fi

      if [ "$json" = true ]; then
        jq -n --arg status "$status" --arg detail "$detail" --arg activeSystem "$active_system" --arg targetSystem "$target_system" \
          --arg StoreIntegrity "$StoreIntegrity" --arg SourceIntegrity "$SourceIntegrity" --arg CommandIntegrity "$CommandIntegrity" --arg BoundaryIntegrity "$BoundaryIntegrity" \
          '{schemaVersion:1,status:$status,detail:$detail,activeSystem:$activeSystem,targetSystem:$targetSystem,StoreIntegrity:$StoreIntegrity,SourceIntegrity:$SourceIntegrity,CommandIntegrity:$CommandIntegrity,BoundaryIntegrity:$BoundaryIntegrity}'
      else
        printf 'AI NixOS self-check: %s\n' "$status"
        printf '  StoreIntegrity: %s\n  SourceIntegrity: %s\n  CommandIntegrity: %s\n  BoundaryIntegrity: %s\n' "$StoreIntegrity" "$SourceIntegrity" "$CommandIntegrity" "$BoundaryIntegrity"
        printf '  Detail: %s\n' "$detail"
      fi
      exit "$exit_code"
    '';
  };
in
{
  environment.systemPackages = [ selfCheck ];
  environment.etc."dataworkstation/ai-nixos-source-manifest".source = sourceManifest;
}
