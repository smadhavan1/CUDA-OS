#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"
configure_chroot_dns

MANIFEST="$CONFIG_DIR/package-manifest.txt"

if [[ ! -s "$MANIFEST" ]]; then
    echo "ERROR: Package manifest is missing or empty: $MANIFEST" >&2
    exit 1
fi

mkdir -p "$LOG_DIR"

PACKAGES_FILE="$(mktemp "$LOG_DIR/packages.XXXXXX")"
trap 'rm -f "$PACKAGES_FILE"' EXIT

awk -F '\t' '
    NF != 2 || $1 == "" || $2 == "" {
        printf "ERROR: Invalid manifest entry at line %d\n", NR > "/dev/stderr"
        exit 1
    }
    $1 !~ /1018-aws/ {
        print $1 "=" $2
    }
' "$MANIFEST" > "$PACKAGES_FILE"

mapfile -t PACKAGES < "$PACKAGES_FILE"

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
    echo "ERROR: No packages found in manifest." >&2
    exit 1
fi

mkdir -p "$ROOTFS/dev/pts" "$ROOTFS/proc" "$ROOTFS/sys" "$ROOTFS/run"

MOUNTS=(
    "$ROOTFS/dev"
    "$ROOTFS/dev/pts"
    "$ROOTFS/proc"
    "$ROOTFS/sys"
    "$ROOTFS/run"
)

for target in "${MOUNTS[@]}"; do
    if mountpoint -q "$target"; then
        echo "ERROR: Already mounted: $target" >&2
        exit 1
    fi
done

cleanup() {
    set +e
    for target in \
        "$ROOTFS/run" \
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

mount --bind /dev "$ROOTFS/dev"
mount --bind /dev/pts "$ROOTFS/dev/pts"
mount -t proc proc "$ROOTFS/proc"
mount -t sysfs sysfs "$ROOTFS/sys"
mount --bind /run "$ROOTFS/run"

echo "Installing initramfs infrastructure before GPU packages..."

chroot "$ROOTFS" apt-get install -y --no-install-recommends \
    "initramfs-tools=0.151ubuntu1"

echo "Completing previously interrupted package configuration..."

chroot "$ROOTFS" dpkg --configure -a

echo "Installing manifest packages: ${#PACKAGES[@]}"

chroot "$ROOTFS" apt-get install -y --no-install-recommends "${PACKAGES[@]}"

chroot "$ROOTFS" apt-get clean

echo "Package installation completed successfully."
