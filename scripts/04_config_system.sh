#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

echo "$IMAGE_NAME" > "$ROOTFS/etc/hostname"

cat > "$ROOTFS/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 $IMAGE_NAME
::1 localhost ip6-localhost ip6-loopback
EOF

echo "en_US.UTF-8 UTF-8" > "$ROOTFS/etc/locale.gen"

chroot "$ROOTFS" locale-gen
chroot "$ROOTFS" update-locale LANG=en_US.UTF-8

ln -sf /usr/share/zoneinfo/Asia/Kolkata "$ROOTFS/etc/localtime"

chroot "$ROOTFS" dpkg-reconfigure -f noninteractive tzdata

cat > "$ROOTFS/etc/os-release" <<EOF
NAME="$IMAGE_NAME"
VERSION="$IMAGE_VERSION"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="$IMAGE_NAME $IMAGE_VERSION"
VERSION_ID="$IMAGE_VERSION"
VERSION_CODENAME=$UBUNTU_CODENAME
EOF

# Create a systemd user service.
mkdir -p "$ROOTFS/etc/systemd/user"

cat > "$ROOTFS/etc/systemd/system/cuda-benchmark.service" <<'EOF'
[Unit]
Description=CUDA-Minimal Automatic Benchmark Service
Wants=systemd-udev-settle.service
After=local-fs.target systemd-udev-settle.service

[Service]
Type=oneshot
ExecStartPre=/bin/bash -c 'for i in {1..60}; do if [ -x /cdrom/benchmarks/scripts/run_all.sh ] && /usr/bin/nvidia-smi -L >/dev/null 2>&1; then exit 0; fi; sleep 2; done; echo "Benchmark prerequisites unavailable." >&2; exit 1'
ExecStart=/bin/bash /cdrom/benchmarks/scripts/run_all.sh
RemainAfterExit=yes
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=no
TTYVHangup=no
TTYVTDisallocate=no
TimeoutStartSec=150

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "$ROOTFS/etc/systemd/system/multi-user.target.wants"

ln -sfn ../cuda-benchmark.service \
    "$ROOTFS/etc/systemd/system/multi-user.target.wants/cuda-benchmark.service"
