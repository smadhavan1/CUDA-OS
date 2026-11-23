#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

mkdir -p "$BUILD_DIR" "$LOG_DIR"

debootstrap \
    --arch="$ARCH" \
    --variant=minbase \
    --include=ca-certificates \
    --components=main,restricted,universe,multiverse \
    "$UBUNTU_CODENAME" \
    "$ROOTFS" \
    "$UBUNTU_MIRROR" \
    2>&1 | tee "$LOG_DIR/01-bootstrap.log"

test -s "$ROOTFS/etc/ssl/certs/ca-certificates.crt"
