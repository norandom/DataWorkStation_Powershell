#!/bin/sh
set -eu
# Do not reformat or reset any existing active swap device.
if awk '$1 == "/dev/zram0" { found=1 } END { exit !found }' /proc/swaps; then
    exit 0
fi
modprobe zram num_devices=1
[ "$(cat /sys/block/zram0/disksize)" = 0 ] || {
    echo 'zram0 is already configured; refusing to reset it.' >&2
    exit 1
}
zramctl --size 2G --algorithm lzo-rle /dev/zram0
mkswap /dev/zram0
swapon --priority 100 /dev/zram0
