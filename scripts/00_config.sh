#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_DIR="$PROJECT_DIR/build"
ROOTFS="$BUILD_DIR/rootfs"
ISO_DIR="$BUILD_DIR/iso"

CONFIG_DIR="$PROJECT_DIR/config"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
LOG_DIR="$PROJECT_DIR/logs"

UBUNTU_CODENAME="resolute"
ARCH="amd64"
UBUNTU_MIRROR="http://archive.ubuntu.com/ubuntu/"

KERNEL_VERSION="7.0.0-44-generic"

NVIDIA_DRIVER_VERSION="595.99.02"

CUDA_VERSION="12.4"
CUDNN_VERSION="9.28.1.4"

NVIDIA_CONTAINER_TOOLKIT_VERSION="1.20.2"

IMAGE_NAME="CUDA-Minimal"
IMAGE_VERSION="1.0"
ISO_NAME="cuda-minimal.iso"
SQUASHFS_COMPRESSION="xz"

BUILD_TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"

export PROJECT_DIR BUILD_DIR ROOTFS ISO_DIR
export CONFIG_DIR SCRIPTS_DIR LOG_DIR
export UBUNTU_CODENAME ARCH UBUNTU_MIRROR
export KERNEL_VERSION NVIDIA_DRIVER_VERSION
export CUDA_VERSION CUDNN_VERSION
export NVIDIA_CONTAINER_TOOLKIT_VERSION
export IMAGE_NAME IMAGE_VERSION ISO_NAME
export SQUASHFS_COMPRESSION BUILD_TIMESTAMP

configure_chroot_dns() {
    local resolver="/run/systemd/resolve/resolv.conf"

    if [[ ! -s "$resolver" ]]; then
        echo "ERROR: Host DNS resolver not found: $resolver" >&2
        return 1
    fi

    rm -f "$ROOTFS/etc/resolv.conf"
    cp "$resolver" "$ROOTFS/etc/resolv.conf"
}
