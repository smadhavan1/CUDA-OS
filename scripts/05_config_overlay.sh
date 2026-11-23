#!/usr/bin/env bash

set -Eeuo pipefail

source "$(dirname "$0")/00_config.sh"

CASPER_SCRIPT="$ROOTFS/usr/share/initramfs-tools/scripts/casper"

if [[ ! -f "$CASPER_SCRIPT" ]]; then
    echo "ERROR: Casper script not found: $CASPER_SCRIPT" >&2
    exit 1
fi

sed -i 's/modprobe "${MP_QUIET}" -b overlay/modprobe ${MP_QUIET} -b overlay/' \
    "$CASPER_SCRIPT"
    
if ! grep -qF 'mkdir -p /root/var/crash' "$CASPER_SCRIPT"; then
    sed -i '/    touch \/root\/var\/crash\/crash.init/i\    mkdir -p /root/var/crash' "$CASPER_SCRIPT"
fi

cat > "$ROOTFS/etc/initramfs-tools/modules" <<EOF
overlay
nvidia
nvidia-uvm
EOF

cat > "$ROOTFS/etc/casper.conf" <<EOF
export USERNAME=ubuntu
export USERFULLNAME="CUDA-Minimal User"
export HOST=ubuntu
export BUILD_SYSTEM=Ubuntu
EOF

UPDATE_HOOK="$ROOTFS/usr/share/initramfs-tools/scripts/casper-bottom/31disable_update_notifier"

if [[ -f "$UPDATE_HOOK" ]] &&
   ! grep -qF 'mkdir -p /root/usr/lib/update-notifier' "$UPDATE_HOOK"; then
    sed -i '/^chroot \/root dpkg-divert/i mkdir -p /root/usr/lib/update-notifier /root/usr/lib/ubuntu-release-upgrader' "$UPDATE_HOOK"
fi

APPORT_HOOK="$ROOTFS/usr/share/initramfs-tools/scripts/casper-bottom/33enable_apport_crashes"

if [[ -f "$APPORT_HOOK" ]]; then
    sed -i \
        's|^if grep -q '\''enabled=0'\'' /root/etc/default/apport; then|if [ -f /root/etc/default/apport ] \&\& grep -q '\''enabled=0'\'' /root/etc/default/apport; then|' \
        "$APPORT_HOOK"
fi

echo "Overlay configuration completed."
