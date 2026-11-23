#!/usr/bin/env bash
set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

SOURCE_ROOTFS="$ROOTFS"

for required in \
    "$SOURCE_ROOTFS/boot/vmlinuz-$KERNEL_VERSION" \
    "$SOURCE_ROOTFS/boot/initrd.img-$KERNEL_VERSION" \
    "$SOURCE_ROOTFS/boot/config-$KERNEL_VERSION" \
    "$SOURCE_ROOTFS/etc/os-release" \
    "$ISO_DIR/casper/filesystem.squashfs"
do
    if [[ ! -s "$required" ]]; then
        echo "ERROR: Required build artifact missing: $required" >&2
        exit 1
    fi
done

for tool in grub-mkstandalone mkfs.vfat mmd mcopy; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "ERROR: Required tool missing: $tool" >&2
        exit 1
    fi
done

if [[ ! -f "$PROJECT_DIR/iso/boot/grub/grub.cfg" ]]; then
    echo "ERROR: GRUB configuration missing." >&2
    exit 1
fi

if [[ ! -f "$PROJECT_DIR/benchmarks/scripts/run_all.sh" ]]; then
    echo "ERROR: Benchmark runner missing." >&2
    exit 1
fi

mkdir -p "$ISO_DIR/casper" "$ISO_DIR/docs"

rsync -a \
    --exclude='/casper/filesystem.squashfs' \
    --exclude='/casper/filesystem.manifest' \
    --exclude='/casper/filesystem.size' \
    --exclude='/casper/vmlinuz' \
    --exclude='/casper/initrd' \
    "$PROJECT_DIR/iso/" "$ISO_DIR/"

cp "$SOURCE_ROOTFS/boot/vmlinuz-$KERNEL_VERSION" "$ISO_DIR/casper/vmlinuz"
cp "$SOURCE_ROOTFS/boot/initrd.img-$KERNEL_VERSION" "$ISO_DIR/casper/initrd"

chmod 644 "$ISO_DIR/casper/vmlinuz" "$ISO_DIR/casper/initrd"

du -sx --block-size=1 "$SOURCE_ROOTFS" | cut -f1 \
    > "$ISO_DIR/casper/filesystem.size"

chroot "$SOURCE_ROOTFS" dpkg-query -W \
    -f='${binary:Package} ${Version}\n' \
    > "$ISO_DIR/casper/filesystem.manifest"

echo "Generating standalone GRUB EFI executable..."

EFI_CONFIG="$(mktemp)"
EFI_EXECUTABLE="$(mktemp)"

cleanup() {
    rm -f "$EFI_CONFIG" "$EFI_EXECUTABLE"
}
trap cleanup EXIT

cat > "$EFI_CONFIG" <<'EOF'
search --no-floppy --label CUDA_MINIMAL --set=root
set root=($root)
set prefix=(memdisk)/boot/grub
configfile ($root)/boot/grub/grub.cfg
EOF

grub-mkstandalone \
    --format=x86_64-efi \
    --output="$EFI_EXECUTABLE" \
    --install-modules="part_gpt part_msdos fat iso9660 udf search search_label normal linux configfile efi_gop" \
    "boot/grub/grub.cfg=$EFI_CONFIG"

echo "Creating EFI FAT image..."

rm -f "$ISO_DIR/efi.img"

truncate -s 8M "$ISO_DIR/efi.img"
mkfs.vfat -F 12 -n CUDAEFI "$ISO_DIR/efi.img"

mmd -i "$ISO_DIR/efi.img" ::/EFI
mmd -i "$ISO_DIR/efi.img" ::/EFI/BOOT

mcopy -i "$ISO_DIR/efi.img" \
    "$EFI_EXECUTABLE" \
    ::/EFI/BOOT/BOOTX64.EFI

echo "EFI image generated successfully."

rm -rf "$ISO_DIR/benchmarks"
cp -a "$PROJECT_DIR/benchmarks" "$ISO_DIR/benchmarks"

rm -rf "$ISO_DIR/docs/config" "$ISO_DIR/docs/scripts"

cp -a "$CONFIG_DIR" "$ISO_DIR/docs/config"
cp -a "$SCRIPTS_DIR" "$ISO_DIR/docs/scripts"

# Document the generated EFI image, not the obsolete source image.
cp "$ISO_DIR/efi.img" "$ISO_DIR/docs/config/efi.img"

mkdir -p "$ISO_DIR/.disk"
printf '%s %s\n' "$IMAGE_NAME" "$IMAGE_VERSION" > "$ISO_DIR/.disk/info"

cd "$ISO_DIR"

find . -type f ! -name md5sum.txt -print0 |
    sort -z |
    xargs -0 md5sum > md5sum.txt

xorriso -as mkisofs \
    -r \
    -iso-level 3 \
    -V "CUDA_MINIMAL" \
    -o "$BUILD_DIR/$ISO_NAME" \
    -J -joliet-long -l \
    -partition_cyl_align off \
    -partition_offset 0 \
    -c boot.catalog \
    -e efi.img \
    -no-emul-boot \
    -efi-boot-part \
    --efi-boot-image \
    "$ISO_DIR"

if [[ ! -s "$BUILD_DIR/$ISO_NAME" ]]; then
    echo "ERROR: ISO generation failed." >&2
    exit 1
fi

echo "ISO created: $BUILD_DIR/$ISO_NAME"
