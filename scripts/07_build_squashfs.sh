#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

if [[ ! -d "$ROOTFS" ]]; then
    echo "ERROR: Root filesystem not found: $ROOTFS" >&2
    exit 1
fi

if [[ ! -d "$ROOTFS/boot" ]]; then
    echo "ERROR: Root filesystem boot directory is missing." >&2
    exit 1
fi

mkdir -p "$ISO_DIR/casper"

mksquashfs "$ROOTFS" "$ISO_DIR/casper/filesystem.squashfs" \
    -comp "$SQUASHFS_COMPRESSION" \
    -b 128K \
    -Xdict-size 64K \
    -processors 2 \
    -noappend \
    -e boot

if [[ ! -s "$ISO_DIR/casper/filesystem.squashfs" ]]; then
    echo "ERROR: SquashFS image was not created." >&2
    exit 1
fi

echo "SquashFS created successfully."
