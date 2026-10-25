#!/bin/sh
# Inside trusted Debian: sh linux/zram.sh Test | sudo sh linux/zram.sh Ensure
set -eu
mode=${1:-Test}
case "$mode" in Test|Ensure) ;; *) echo 'Usage: zram.sh [Test|Ensure]' >&2; exit 2 ;; esac
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../config" && pwd)
desired="$source_dir/workstation-zram.service"
target=/etc/systemd/system/workstation-zram.service
helper="$source_dir/../linux/start-zram.sh"
installed_helper=/usr/local/libexec/workstation-zram
test_state() {
    cmp -s "$desired" "$target" &&
    cmp -s "$helper" "$installed_helper" &&
    systemctl is-enabled --quiet workstation-zram.service &&
    systemctl is-active --quiet workstation-zram.service &&
    [ "$(cat /sys/block/zram0/disksize)" = 2147483648 ] &&
    grep -Fq '[lzo-rle]' /sys/block/zram0/comp_algorithm &&
    awk '$1 == "/dev/zram0" && $5 == 100 { found=1 } END { exit !found }' /proc/swaps
}
if [ "$mode" = Test ]; then
    if test_state; then echo 'zram: compliant.'; else echo 'zram: drift detected.'; exit 1; fi
    exit 0
fi
[ "$(id -u)" -eq 0 ] || { echo 'Ensure requires root.' >&2; exit 1; }
if test_state; then echo 'zram: already compliant.'; exit 0; fi
# Never reset or swap off a live device to resolve configuration drift.
if awk '$1 == "/dev/zram0" { found=1 } END { exit !found }' /proc/swaps; then
    echo 'Active zram0 differs from desired state; inspect it before changing configuration.' >&2
    exit 1
fi
modinfo zram >/dev/null
if [ -r /sys/module/zswap/parameters/enabled ] && grep -qi '^y' /sys/module/zswap/parameters/enabled; then
    echo 'zswap is enabled; resolve the compression policy before adding zram.' >&2
    exit 1
fi
command -v zramctl >/dev/null
command -v mkswap >/dev/null
command -v swapon >/dev/null
install -d -m 0755 /usr/local/libexec
if [ -f "$target" ]; then cp -p "$target" "$target.$(date +%Y%m%d-%H%M%S).bak"; fi
if [ -f "$installed_helper" ]; then cp -p "$installed_helper" "$installed_helper.$(date +%Y%m%d-%H%M%S).bak"; fi
install -m 0644 "$desired" "$target"
install -m 0755 "$helper" "$installed_helper"
systemctl daemon-reload
systemctl enable --now workstation-zram.service
test_state
echo 'zram: compliant; active now and configured for future boots.'
