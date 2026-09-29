#!/bin/sh
# Tests for ../check-image.sh. Each case builds a fake image root in a temp
# directory and checks the exit code and the failure message.

set -eu

here=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
check="$here/../check-image.sh"
fw="$here/../firmware"
kver=6.17.0-1032-oem
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

vgpr_line='  * drm/amdkfd: bump minimum vgpr size for gfx1151'
export_line='  * drm/amdkfd: Export the cwsr_size and ctl_stack_size to userspace'

# make_root DIR: a root that passes every check.
make_root() {
    r=$1
    mkdir -p "$r/lib/modules/$kver" "$r/usr/share/doc/linux-modules-$kver" \
        "$r/lib/firmware/updates/amdgpu" "$r/boot"
    printf '%s\n%s\n%s\n' "linux-oem-6.17 ($kver)" "$vgpr_line" "$export_line" |
        gzip -c > "$r/usr/share/doc/linux-modules-$kver/changelog.Debian.gz"
    cp "$fw/gc_11_5_1_mes_2.bin.zst" "$fw/gc_11_5_1_mes1.bin.zst" \
        "$r/lib/firmware/updates/amdgpu/"
    echo kernel > "$r/boot/vmlinuz-$kver"
    ln -s "vmlinuz-$kver" "$r/boot/vmlinuz"
}

# fake_lsinitrd FILE CONTENT: a script that prints CONTENT, used as LSINITRD.
fake_lsinitrd() {
    printf '#!/bin/sh\ncat <<"EOT"\n%s\nEOT\n' "$2" > "$1"
    chmod +x "$1"
}

expect_pass() {
    name=$1; root=$2
    if out=$("$check" "$root" 2>&1); then
        echo "ok   $name"
    else
        echo "FAIL $name: expected pass, got: $out"; failures=$((failures + 1))
    fi
}

expect_fail() {
    name=$1; root=$2; want=$3
    if out=$("$check" "$root" 2>&1); then
        echo "FAIL $name: expected failure, got: $out"; failures=$((failures + 1))
    elif printf '%s' "$out" | grep -Fq "$want"; then
        echo "ok   $name"
    else
        echo "FAIL $name: wanted '$want', got: $out"; failures=$((failures + 1))
    fi
}

r=$work/good; make_root "$r"
LSINITRD=/bin/false expect_pass "good root, no initrd" "$r"

r=$work/two-kernels; make_root "$r"
mkdir -p "$r/lib/modules/6.8.0-90-generic"
expect_fail "two kernels" "$r" "expected exactly one kernel"

r=$work/generic; make_root "$r"
mv "$r/lib/modules/$kver" "$r/lib/modules/6.14.0-36-generic"
expect_fail "generic kernel" "$r" "is not an -oem kernel"

r=$work/no-changelog; make_root "$r"
rm "$r/usr/share/doc/linux-modules-$kver/changelog.Debian.gz"
expect_fail "missing changelog" "$r" "changelog not found"

r=$work/no-vgpr; make_root "$r"
printf '%s\n' "$export_line" |
    gzip -c > "$r/usr/share/doc/linux-modules-$kver/changelog.Debian.gz"
expect_fail "changelog without vgpr fix" "$r" "bump minimum vgpr size for gfx1151"

r=$work/no-export; make_root "$r"
printf '%s\n' "$vgpr_line" |
    gzip -c > "$r/usr/share/doc/linux-modules-$kver/changelog.Debian.gz"
expect_fail "changelog without export fix" "$r" "Export the cwsr_size and ctl_stack_size"

r=$work/fw-missing; make_root "$r"
rm "$r/lib/firmware/updates/amdgpu/gc_11_5_1_mes1.bin.zst"
expect_fail "missing firmware" "$r" "gc_11_5_1_mes1.bin.zst"

r=$work/fw-tampered; make_root "$r"
printf 'not the pinned blob' | zstd -q -f -o "$r/lib/firmware/updates/amdgpu/gc_11_5_1_mes_2.bin.zst"
expect_fail "tampered firmware" "$r" "gc_11_5_1_mes_2.bin.zst does not match"

r=$work/vmlinuz-other; make_root "$r"
echo other > "$r/boot/vmlinuz-6.8.0-90-generic"
ln -sfn vmlinuz-6.8.0-90-generic "$r/boot/vmlinuz"
expect_fail "vmlinuz points elsewhere" "$r" "/boot/vmlinuz is not vmlinuz-$kver"

r=$work/vmlinuz-copy; make_root "$r"
rm "$r/boot/vmlinuz"; cp "$r/boot/vmlinuz-$kver" "$r/boot/vmlinuz"
expect_pass "vmlinuz is a copy of the OEM kernel" "$r"

r=$work/initrd-ok; make_root "$r"; echo initrd > "$r/boot/initrd"
fake_lsinitrd "$work/ls-ok" "usr/lib/modules/$kver/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko.zst
usr/lib/firmware/updates/amdgpu/gc_11_5_1_mes_2.bin.zst
usr/lib/firmware/updates/amdgpu/gc_11_5_1_mes1.bin.zst"
LSINITRD=$work/ls-ok expect_pass "initrd has amdgpu and pinned firmware" "$r"

r=$work/initrd-no-amdgpu; make_root "$r"; echo initrd > "$r/boot/initrd"
fake_lsinitrd "$work/ls-noamd" "usr/lib/modules/$kver/kernel/fs/overlayfs/overlay.ko.zst"
LSINITRD=$work/ls-noamd expect_pass "initrd without amdgpu" "$r"

r=$work/initrd-bad; make_root "$r"; echo initrd > "$r/boot/initrd"
fake_lsinitrd "$work/ls-bad" "usr/lib/modules/$kver/kernel/drivers/gpu/drm/amd/amdgpu/amdgpu.ko.zst
usr/lib/firmware/amdgpu/gc_11_5_1_mes_2.bin.zst"
LSINITRD=$work/ls-bad expect_fail "initrd has amdgpu but not the pinned firmware" "$r" "initramfs has amdgpu.ko but not updates/amdgpu/gc_11_5_1_mes_2.bin.zst"

r=$work/initrd-no-tool; make_root "$r"; echo initrd > "$r/boot/initrd"
LSINITRD=/nonexistent/lsinitrd expect_fail "initrd but no lsinitrd" "$r" "cannot list the initramfs"

if [ "$failures" -ne 0 ]; then
    echo "$failures test(s) failed"; exit 1
fi
echo "all tests passed"
