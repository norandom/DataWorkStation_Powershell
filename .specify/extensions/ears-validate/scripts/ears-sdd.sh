#!/usr/bin/env sh
set -eu

if command -v ears-sdd >/dev/null 2>&1; then
  exec ears-sdd "$@"
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
if command -v python3 >/dev/null 2>&1; then
  exec python3 "$script_dir/ears_sdd.py" "$@"
fi

echo "Install the versioned spec-kit-ears-tdd tool release before running this command." >&2
exit 2
