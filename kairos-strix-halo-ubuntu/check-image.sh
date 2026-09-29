#!/bin/sh
# Build-time checks for the kairos-strix-halo-ubuntu image.
#
# Usage: check-image.sh [ROOT]   (ROOT defaults to /)
#
# The image exists for one reason: strix (Radeon 8060S, gfx1151) needs a
# kernel with the gfx1151 CWSR/VGPR fix, or the GPU hangs under ROCm load
# ("MES failed to respond to msg=REMOVE_QUEUE"). This script fails the build
# if the image does not have that kernel, or if the pinned MES firmware is
# not in place. LSINITRD names the initramfs listing command (for tests).

set -eu

root=${1:-/}
root=${root%/}
lsinitrd=${LSINITRD:-lsinitrd}

fail() {
    echo "check-image: FAIL: $*" >&2
    exit 1
}

for tool in zstd gzip sha256sum cmp; do
    command -v "$tool" >/dev/null 2>&1 || fail "'$tool' is needed but not installed"
done

# 1. Exactly one kernel, and it is an OEM kernel.
set -- "$root"/lib/modules/*
[ "$#" -eq 1 ] && [ -d "$1" ] ||
    fail "expected exactly one kernel in /lib/modules, found: $(ls "$root/lib/modules" | tr '\n' ' ')"
kver=$(basename "$1")
case $kver in
    *-oem) ;;
    *) fail "$kver is not an -oem kernel" ;;
esac

# 2. The kernel has the gfx1151 fix. Ubuntu lists cherry-picked upstream
# commits by title in the changelog. A string search in amdgpu.ko does not
# work: unfixed kernels also contain "cwsr_size".
changelog=$root/usr/share/doc/linux-modules-$kver/changelog.Debian.gz
[ -f "$changelog" ] || fail "changelog not found: /usr/share/doc/linux-modules-$kver/changelog.Debian.gz"
for fix in \
    'drm/amdkfd: bump minimum vgpr size for gfx1151' \
    'drm/amdkfd: Export the cwsr_size and ctl_stack_size to userspace'; do
    gzip -dc "$changelog" | grep -Fq "$fix" ||
        fail "kernel $kver changelog does not contain '$fix'"
done

# 3. /boot/vmlinuz is the OEM kernel (Kairos boots /boot/vmlinuz).
[ -f "$root/boot/vmlinuz-$kver" ] || fail "/boot/vmlinuz-$kver not found"
vmlinuz=$root/boot/vmlinuz
if [ -L "$vmlinuz" ]; then
    [ "$(basename "$(readlink "$vmlinuz")")" = "vmlinuz-$kver" ] ||
        fail "/boot/vmlinuz is not vmlinuz-$kver (points to $(readlink "$vmlinuz"))"
elif [ -f "$vmlinuz" ]; then
    cmp -s "$vmlinuz" "$root/boot/vmlinuz-$kver" ||
        fail "/boot/vmlinuz is not vmlinuz-$kver"
else
    fail "/boot/vmlinuz not found"
fi

# 4. The pinned MES firmware (MES 0x80 / MES_KIQ 0x6f, see firmware/README.md).
fwdir=$root/lib/firmware/updates/amdgpu
while read -r sum name; do
    [ -f "$fwdir/$name" ] || fail "pinned firmware missing: /lib/firmware/updates/amdgpu/$name"
    got=$(zstd -qdc "$fwdir/$name" 2>/dev/null | sha256sum | cut -d' ' -f1)
    [ "$got" = "$sum" ] ||
        fail "/lib/firmware/updates/amdgpu/$name does not match the pinned blob (got $got)"
done <<'EOF'
8e07832c18d87b7643fc221633d841a5fa3bae0e7d2aad1f2b212e190f963a0a gc_11_5_1_mes_2.bin.zst
5ad61e89d051652aada3664005df436a7694d872a5c0865eb121e03424db8588 gc_11_5_1_mes1.bin.zst
EOF

# 5. Kairos boots /boot/initrd, so it must exist and be built for the OEM
# kernel. If amdgpu loads from the initramfs, the pinned firmware must be
# there too, or early boot loads the stock blob.
[ -f "$root/boot/initrd" ] || fail "initramfs /boot/initrd not found"
listing=$("$lsinitrd" "$root/boot/initrd" 2>/dev/null) ||
    fail "cannot list the initramfs with '$lsinitrd'"
printf '%s\n' "$listing" | grep -Fq "lib/modules/$kver/" ||
    fail "initramfs is not built for $kver"
if printf '%s\n' "$listing" | grep -q '/amdgpu\.ko'; then
    for name in gc_11_5_1_mes_2.bin.zst gc_11_5_1_mes1.bin.zst; do
        printf '%s\n' "$listing" | grep -Fq "firmware/updates/amdgpu/$name" ||
            fail "initramfs has amdgpu.ko but not updates/amdgpu/$name"
    done
fi

echo "check-image: OK ($kver)"
