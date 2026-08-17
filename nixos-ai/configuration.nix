{ pkgs, ... }:

let
  opencode = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode";
    version = "1.18.18";
    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz";
      hash = "sha256-DN3CIkGLhVNmmQWomAwM2nCI8A2iTYPWrHawHJ/bKq8=";
    };
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.gnutar pkgs.gzip ];
    installPhase = ''
      mkdir -p "$out/bin"
      tar -xzf "$src"
      install -m 0555 opencode "$out/bin/opencode"
    '';
  };

  opencodeSandbox = pkgs.writeShellApplication {
    name = "opencode-sandbox";
    runtimeInputs = with pkgs; [ coreutils gnugrep jq ];
    text = ''
      set -eu
      if [ "''${1-}" = "--check-only" ]; then
        check_only=true
        shift
      else
        check_only=false
      fi
      project="''${1-}"
      [ -n "$project" ] || { printf 'Usage: opencode-sandbox [--check-only] <private-project> [arguments...]\n' >&2; exit 64; }
      shift
      project="$(readlink -f -- "$project")"
      case "$project" in
        "$HOME/projects/"*) ;;
        *) printf 'Project must resolve beneath $HOME/projects.\n' >&2; exit 2 ;;
      esac
      [ -d "$project" ] || { printf 'Project does not exist: %s\n' "$project" >&2; exit 2; }

      nono=/home/linuxbrew/.linuxbrew/bin/nono
      profile=/etc/nono/opencode-profile.json
      [ -x "$nono" ] || { printf 'nono is missing from the maintenance-owned Homebrew prefix.\n' >&2; exit 2; }
      [ "$(stat -c %U "$nono")" != "$(id -un)" ] || { printf 'The daily AI user must not own nono.\n' >&2; exit 2; }
      [ "$(sha256sum "$profile" | cut -d' ' -f1)" = "92c45dc500d8b30cb8e8b2372677697b0b94b6835fd68765d268b37769d3bbe9" ] || {
        printf 'The reviewed nono profile changed.\n' >&2; exit 2;
      }
      "$nono" profile validate "$profile" >/dev/null
      setup_output="$("$nono" setup --check-only 2>&1)" || { printf '%s\n' "$setup_output" >&2; exit 2; }
      printf '%s\n' "$setup_output" | grep -q 'TCP network rule support verified' || {
        printf 'NetworkEnforcement unavailable: secure Landlock TCP rules were not verified.\n' >&2; exit 2;
      }
      for denied in "$HOME/.ssh" "$HOME/.aws" /mnt /mnt/wsl /var/run/docker.sock "/run/user/$(id -u)/bus"; do
        why_json="$("$nono" why --profile "$profile" --path "$denied" --op read --json 2>/dev/null)" || {
          printf 'Could not verify the reviewed denial for %s.\n' "$denied" >&2
          exit 2
        }
        if ! printf '%s\n' "$why_json" | jq -e '(.status | ascii_downcase) == "denied"' >/dev/null; then
          printf 'Reviewed denial failed for %s.\n' "$denied" >&2
          exit 2
        fi
      done
      "$nono" run --profile "$profile" --dry-run -- opencode >/dev/null
      if [ "$check_only" = true ]; then
        printf 'OpenCode sandbox preflight: compliant\n'
        exit 0
      fi
      cd "$project"
      exec "$nono" run --profile "$profile" -- opencode "$@"
    '';
  };
in
{
  imports = [ ./self-check.nix ];

  wsl = {
    enable = true;
    wslConf = {
      interop = {
        enabled = false;
        appendWindowsPath = false;
      };
      automount.enabled = false;
    };
  };

  networking.hostName = "nixos-ai-wsl";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };

  users.groups.ai-maint = { };
  users.users.ai-maint = {
    isSystemUser = true;
    group = "ai-maint";
    home = "/home/linuxbrew";
    createHome = true;
    shell = "${pkgs.shadow}/bin/nologin";
  };

  environment.systemPackages = with pkgs; [
    bash
    coreutils
    curl
    file
    gcc
    git
    gnumake
    jq
    opencode
    opencodeSandbox
    procps
  ];

  environment.etc."nono/opencode-profile.json".source = ./opencode-profile.json;
  system.stateVersion = "26.05";
}
