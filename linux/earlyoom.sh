#!/bin/sh
# Run from Debian: sh linux/earlyoom.sh Test | sudo sh linux/earlyoom.sh Ensure
set -eu
mode=${1:-Test}
case "$mode" in Test|Ensure) ;; *) echo 'Usage: earlyoom.sh [Test|Ensure]' >&2; exit 2 ;; esac
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../config" && pwd)
desired="$source_dir/earlyoom.default"
target=/etc/default/earlyoom
test_state() {
    command -v earlyoom >/dev/null 2>&1 &&
    cmp -s "$desired" "$target" &&
    systemctl is-enabled --quiet earlyoom &&
    systemctl is-active --quiet earlyoom
}
if [ "$mode" = Test ]; then
    if test_state; then echo 'earlyoom: compliant.'; else echo 'earlyoom: drift detected.'; exit 1; fi
    exit 0
fi
[ "$(id -u)" -eq 0 ] || { echo 'Ensure requires root.' >&2; exit 1; }
if test_state; then echo 'earlyoom: already compliant.'; exit 0; fi
# Write the policy before package installation can start the service.
if [ -f "$target" ]; then cp -p "$target" "$target.$(date +%Y%m%d-%H%M%S).bak"; fi
install -m 0644 "$desired" "$target"
if ! command -v earlyoom >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::=--force-confold install -y earlyoom
fi
systemctl enable earlyoom
systemctl restart earlyoom
test_state
echo 'earlyoom: compliant; service enabled and running.'
