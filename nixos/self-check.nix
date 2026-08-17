{ pkgs, ... }:

let
  sourceManifest = pkgs.writeText "dataworkstation-nixos-source-manifest" ''
    ${builtins.hashFile "sha256" ./flake.nix}  /etc/nixos/flake.nix
    ${builtins.hashFile "sha256" ./flake.lock}  /etc/nixos/flake.lock
    ${builtins.hashFile "sha256" ./configuration.nix}  /etc/nixos/configuration.nix
    ${builtins.hashFile "sha256" ./local.nix}  /etc/nixos/local.nix
    ${builtins.hashFile "sha256" ./self-check.nix}  /etc/nixos/self-check.nix
  '';

  selfCheck = pkgs.writeShellApplication {
    name = "workstation-self-check";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      nix
    ];
    text = ''
      json=false
      case "''${1-}" in
        "") ;;
        --json) json=true ;;
        *) printf 'Usage: workstation-self-check [--json]\n' >&2; exit 64 ;;
      esac

      active_system="$(readlink -f /run/current-system)"
      target_system=""
      store_integrity=verified
      source_integrity=matched
      command_integrity=verified
      boundary_integrity=verified
      detail="Active generation matches the deployed flake and its Nix store closure is intact."
      status=compliant
      exit_code=0

      if ! nix store verify --all --no-trust >/dev/null 2>&1; then
        store_integrity=failed
        status=altered
        detail="The complete Nix store failed content verification."
        exit_code=2
      fi

      if ! sha256sum --check --status /etc/dataworkstation/nixos-source-manifest; then
        source_integrity=changed
        if [ "$status" = compliant ]; then
          status=drifted
          detail="The deployed Nix source differs from the source embedded in the active generation."
          exit_code=1
        fi
      fi

      for command_name in helm kubectl pulumi ssh workstation-self-check; do
        command_path="$(command -v "$command_name" 2>/dev/null || true)"
        resolved_path="$(readlink -f "$command_path" 2>/dev/null || true)"
        case "$resolved_path" in
          /nix/store/*) ;;
          *)
            command_integrity=failed
            status=altered
            detail="A managed command resolves outside the Nix store: $command_name"
            exit_code=2
            break
            ;;
        esac
      done

      if ! grep -A4 -E '^\[interop\]' /etc/wsl.conf | grep -Eq '^enabled[[:space:]]*=[[:space:]]*false' ||
         ! grep -A4 -E '^\[interop\]' /etc/wsl.conf | grep -Eq '^appendWindowsPath[[:space:]]*=[[:space:]]*false' ||
         ! grep -A3 -E '^\[automount\]' /etc/wsl.conf | grep -Eq '^enabled[[:space:]]*=[[:space:]]*false' ||
         findmnt -rn -o TARGET | grep -Eq '^/mnt/(c|d|wsl)(/|$)'; then
        boundary_integrity=failed
        status=altered
        detail="The DevOps WSL host-integration boundary failed."
        exit_code=2
      fi

      if target_system="$(nix eval --raw /etc/nixos#nixosConfigurations.workstation.config.system.build.toplevel.outPath 2>/dev/null)"; then
        if [ "$status" = compliant ] && [ "$active_system" != "$target_system" ]; then
          status=drifted
          detail="The evaluated flake target differs from the active NixOS generation."
          exit_code=1
        fi
      else
        if [ "$status" = compliant ]; then
          status=drifted
          detail="The deployed flake cannot be evaluated."
          exit_code=1
        fi
      fi

      if [ "$json" = true ]; then
        jq -n \
          --arg status "$status" \
          --arg detail "$detail" \
          --arg activeSystem "$active_system" \
          --arg targetSystem "$target_system" \
          --arg storeIntegrity "$store_integrity" \
          --arg sourceIntegrity "$source_integrity" \
          --arg commandIntegrity "$command_integrity" \
          --arg boundaryIntegrity "$boundary_integrity" \
          '{schemaVersion:1,status:$status,detail:$detail,activeSystem:$activeSystem,targetSystem:$targetSystem,storeIntegrity:$storeIntegrity,sourceIntegrity:$sourceIntegrity,commandIntegrity:$commandIntegrity,boundaryIntegrity:$boundaryIntegrity}'
      else
        printf 'NixOS WSL self-check: %s\n' "$status"
        printf '  Store integrity: %s\n' "$store_integrity"
        printf '  Source integrity: %s\n' "$source_integrity"
        printf '  Command integrity: %s\n' "$command_integrity"
        printf '  Boundary integrity: %s\n' "$boundary_integrity"
        printf '  Active system: %s\n' "$active_system"
        printf '  Target system: %s\n' "''${target_system:-unavailable}"
        printf '  Detail: %s\n' "$detail"
      fi

      exit "$exit_code"
    '';
  };
in
{
  environment.systemPackages = [ selfCheck ];
  environment.etc."dataworkstation/nixos-source-manifest".source = sourceManifest;
}
