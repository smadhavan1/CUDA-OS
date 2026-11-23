#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

ISO="$BUILD_DIR/$ISO_NAME"
SQUASHFS="$ISO_DIR/casper/filesystem.squashfs"

for file in "$ISO" "$SQUASHFS" \
    "$ISO_DIR/casper/vmlinuz" \
    "$ISO_DIR/casper/initrd" \
    "$ROOTFS/boot/config-$KERNEL_VERSION"
do
    if [[ ! -s "$file" ]]; then
        echo "ERROR: Missing or empty artifact: $file" >&2
        exit 1
    fi
done

echo "Image: $ISO"

echo "ISO size:"
du -h "$ISO"

echo "SHA256:"
sha256sum "$ISO"

echo "SquashFS:"
unsquashfs -s "$SQUASHFS"

echo "Kernel:"
ls -lh "$ISO_DIR/casper/vmlinuz"

echo "Initramfs:"
ls -lh "$ISO_DIR/casper/initrd"

echo "Package count:"
chroot "$ROOTFS" dpkg-query -f '${binary:Package}\n' -W | wc -l

echo "Kernel configuration:"
ls -lh "$ROOTFS/boot/config-$KERNEL_VERSION"

echo "Verification completed."
