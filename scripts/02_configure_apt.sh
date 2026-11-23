#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

mkdir -p "$ROOTFS/etc/apt/apt.conf.d"
mkdir -p "$ROOTFS/etc/apt/sources.list.d"
mkdir -p "$ROOTFS/etc/apt/preferences.d"
mkdir -p "$ROOTFS/usr/share/keyrings"

if [[ ! -s "$ROOTFS/etc/ssl/certs/ca-certificates.crt" ]]; then
    echo "ERROR: CA certificates are missing." >&2
    exit 1
fi

rm -f "$ROOTFS/etc/apt/sources.list"

cp "$CONFIG_DIR/keyrings/cuda-archive-keyring.gpg" \
    "$ROOTFS/usr/share/keyrings/"

cat > "$ROOTFS/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: $UBUNTU_CODENAME ${UBUNTU_CODENAME}-updates ${UBUNTU_CODENAME}-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: ${UBUNTU_CODENAME}-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF

cat > "$ROOTFS/etc/apt/sources.list.d/cuda-ubuntu2604-x86_64.list" <<EOF
deb [signed-by=/usr/share/keyrings/cuda-archive-keyring.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2604/x86_64/ /
EOF

cat > "$ROOTFS/etc/apt/preferences.d/cuda-repository-pin-600" <<EOF
Package: nsight-compute
Pin: origin *ubuntu.com*
Pin-Priority: -1

Package: nsight-systems
Pin: origin *ubuntu.com*
Pin-Priority: -1

Package: *
Pin: release l=NVIDIA CUDA
Pin-Priority: 600
EOF

cat > "$ROOTFS/etc/apt/apt.conf.d/99minimal" <<EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF

chroot "$ROOTFS" apt-get update
