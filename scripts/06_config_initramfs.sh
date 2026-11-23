#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

if [[ ! -d "$ROOTFS" ]]; then
    echo "ERROR: Root filesystem does not exist: $ROOTFS" >&2
    exit 1
fi

mkdir -p "$ROOTFS/dev/pts" "$ROOTFS/proc" "$ROOTFS/sys"

for target in \
    "$ROOTFS/dev" \
    "$ROOTFS/dev/pts" \
    "$ROOTFS/proc" \
    "$ROOTFS/sys"
do
    if mountpoint -q "$target"; then
        echo "ERROR: Already mounted: $target" >&2
        exit 1
    fi
done

cleanup() {
    set +e

    for target in \
        "$ROOTFS/sys" \
        "$ROOTFS/proc" \
        "$ROOTFS/dev/pts" \
        "$ROOTFS/dev"
    do
        if mountpoint -q "$target"; then
            umount "$target" || echo "WARNING: Could not unmount $target" >&2
        fi
    done
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mount --bind /dev "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
mount -t proc proc "$ROOTFS/proc"
mount -t sysfs sysfs "$ROOTFS/sys"

chroot "$ROOTFS" update-initramfs -u -k "$KERNEL_VERSION"

echo "Initramfs updated successfully."
