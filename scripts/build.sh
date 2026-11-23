#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/00_config.sh"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script with sudo." >&2
    exit 1
fi

if [[ -e "$ROOTFS" || -e "$ISO_DIR" ]]; then
    echo "ERROR: Build directories already exist." >&2
    exit 1
fi

mkdir -p "$BUILD_DIR" "$LOG_DIR"

BUILD_LOG="$LOG_DIR/build-$BUILD_TIMESTAMP.log"

exec > >(tee -a "$BUILD_LOG") 2>&1

run_stage() {
    local script="$1"

    echo
    echo "Starting: $script"

    bash "$SCRIPT_DIR/$script"

    echo "Completed: $script"
}

echo "CUDA-Minimal build started."
echo "Project: $PROJECT_DIR"
echo "Build log: $BUILD_LOG"

run_stage 01_bootstrap.sh
run_stage 02_configure_apt.sh
run_stage 03_package_install.sh
run_stage 04_config_system.sh
run_stage 05_config_overlay.sh
run_stage 06_config_initramfs.sh
run_stage 07_build_squashfs.sh
run_stage 08_create_image.sh
run_stage 09_verification.sh

echo "CUDA-Minimal build completed successfully."
echo "ISO: $BUILD_DIR/$ISO_NAME"
