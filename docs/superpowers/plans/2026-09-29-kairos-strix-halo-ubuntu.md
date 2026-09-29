# kairos-strix-halo-ubuntu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Kairos Ubuntu 24.04 image for strix (gfx1151) that ships the
Ubuntu OEM 6.17 kernel with the CWSR/VGPR fix and pinned known-good MES
firmware, roll it out to strix, and remove `amdgpu.cwsr_enable=0`.

**Architecture:** A new standalone image directory `kairos-strix-halo-ubuntu/`
that copies the `kairos-wifi-ubuntu` build. `kairos-init` runs with
`--skip-step installKernel`, then the image installs `linux-image-oem-24.04`,
then `kairos-init` builds the initramfs. A POSIX `sh` check script
(`check-image.sh ROOT`) runs as the last build step and fails the build if the
kernel or firmware is wrong. Tests run that script against fake root
directories.

**Tech Stack:** Dockerfile (BuildKit), kairos-init v4.3.0, Ubuntu 24.04,
POSIX sh, zstd, gzip, sha256sum, dracut `lsinitrd`.

**Spec:** `docs/superpowers/specs/2026-09-29-kairos-strix-halo-ubuntu-design.md`

## Global Constraints

- Repo: `~/_git/dockerfiles`, branch `master`. Commit style: conventional
  commits with a scope, for example `feat(kairos-strix-halo-ubuntu): ...`.
  Every commit message ends with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Do NOT stage or commit `.github/workflows/images.yaml` or `tests/`. They
  hold the owner's uncommitted work. Always `git add` explicit paths, never
  `git add -A` or `git add .`.
- Pins, copied from `kairos-wifi-ubuntu/Dockerfile`:
  `quay.io/kairos/kairos-init:v4.3.0`, `ubuntu:24.04`, `VERSION=v4.3.0`,
  `K8S_PROVIDER=k3s`, `K8S_VERSION=v1.34.11+k3s1`.
- The Dockerfile must contain the literal strings
  `FROM quay.io/kairos/kairos-init:v4.3.0 AS kairos-init`,
  `/kairos-init -l debug -s install` and `/kairos-init -l debug -s init`
  (the owner's `tests/check-kairos-release.sh` greps for them).
- Kernel: `linux-image-oem-24.04` (today `6.17.0-1032-oem`). The installed
  kernel's `linux-modules-<ver>` changelog must contain both
  `drm/amdkfd: bump minimum vgpr size for gfx1151` and
  `drm/amdkfd: Export the cwsr_size and ctl_stack_size to userspace`.
- Pinned MES firmware (from strix, `linux-firmware 20240318.git3b128b60-0ubuntu2.21`):

  | File | sha256 of the `.zst` file | sha256 decompressed |
  |---|---|---|
  | `gc_11_5_1_mes_2.bin.zst` | `902fcd7af743f542b668d5ec11507e79a87f9623f05334f26ec988a3fa02d0c2` | `8e07832c18d87b7643fc221633d841a5fa3bae0e7d2aad1f2b212e190f963a0a` |
  | `gc_11_5_1_mes1.bin.zst` | `bdd16d34154f5eeaf56f19352095215c80c4ee1f4e9648dab0fbda27bbcbc6c0` | `5ad61e89d051652aada3664005df436a7694d872a5c0865eb121e03424db8588` |

- Access to strix: `ssh mudler@strix.casa`, root commands with `sudo -n`,
  kubectl as `sudo -n k3s kubectl`. There is no local kubeconfig.
- A local `docker build` of this image needs about 15 GB free on `/`. On
  2026-09-29 the dev box had 270 MB free. Task 4 checks this first.

## Review Focus

1. **`linux-image-oem-24.04` moves to a new kernel.** The build must still
   pass if the new changelog keeps the fix lines, and must fail if a second
   kernel appears. Covered in Task 2 (two-kernel test, missing-changelog-line
   tests).
2. **Noble changes `/lib/firmware/amdgpu/gc_11_5_1_mes_2.bin.zst`.** The image
   must still boot the pinned blob, because `updates/` wins, and the build
   must fail if the pinned blob itself is wrong or missing. Covered in Task 2
   (tampered and missing firmware tests).
3. **amdgpu loads from the initramfs.** The initramfs must carry the pinned
   `updates/` blobs, or early boot loads noble's blob. Covered in Task 2
   (fake `lsinitrd` tests) and Task 4 (a real `lsinitrd` on the built image).
4. **`/boot/vmlinuz` points to a kernel that is not the OEM one.** Kairos boots
   `/boot/vmlinuz`. Covered in Task 2 (vmlinuz mismatch test) and Task 4.
5. **strix loses Wi-Fi or storage after the upgrade.** Covered in Task 6
   step 3 (Wi-Fi, NAS, zram, pods, notary checks before removing the
   workaround).

---

### Task 1: Vendor the pinned MES firmware

**Files:**
- Create: `kairos-strix-halo-ubuntu/firmware/gc_11_5_1_mes_2.bin.zst`
- Create: `kairos-strix-halo-ubuntu/firmware/gc_11_5_1_mes1.bin.zst`
- Create: `kairos-strix-halo-ubuntu/firmware/LICENSE.amdgpu`
- Create: `kairos-strix-halo-ubuntu/firmware/SHA256SUMS`
- Create: `kairos-strix-halo-ubuntu/firmware/README.md`

**Interfaces:**
- Produces: the directory `kairos-strix-halo-ubuntu/firmware/` with the two
  `.zst` blobs. Task 2's tests and Task 4's Dockerfile read them by these
  exact file names.

- [ ] **Step 1: Write the check first and see it fail**

Run:
```bash
cd ~/_git/dockerfiles
mkdir -p kairos-strix-halo-ubuntu/firmware
cat > kairos-strix-halo-ubuntu/firmware/SHA256SUMS <<'EOF'
902fcd7af743f542b668d5ec11507e79a87f9623f05334f26ec988a3fa02d0c2  gc_11_5_1_mes_2.bin.zst
bdd16d34154f5eeaf56f19352095215c80c4ee1f4e9648dab0fbda27bbcbc6c0  gc_11_5_1_mes1.bin.zst
EOF
(cd kairos-strix-halo-ubuntu/firmware && sha256sum -c SHA256SUMS)
```
Expected: FAIL, `No such file or directory` for both blobs.

- [ ] **Step 2: Copy the blobs from strix**

```bash
cd ~/_git/dockerfiles/kairos-strix-halo-ubuntu/firmware
scp mudler@strix.casa:/lib/firmware/amdgpu/gc_11_5_1_mes_2.bin.zst .
scp mudler@strix.casa:/lib/firmware/amdgpu/gc_11_5_1_mes1.bin.zst .
```

If strix is no longer on `0ubuntu2.21` firmware, the hashes will not match in
Step 3. In that case, stop and report it. Do not accept other blobs.

- [ ] **Step 3: Verify both hashes**

Run:
```bash
cd ~/_git/dockerfiles/kairos-strix-halo-ubuntu/firmware
sha256sum -c SHA256SUMS
zstd -qdc gc_11_5_1_mes_2.bin.zst | sha256sum
zstd -qdc gc_11_5_1_mes1.bin.zst | sha256sum
```
Expected: both `OK`, then `8e07832c18d87b7643fc221633d841a5fa3bae0e7d2aad1f2b212e190f963a0a`
and `5ad61e89d051652aada3664005df436a7694d872a5c0865eb121e03424db8588`.

- [ ] **Step 4: Add the license**

```bash
cd ~/_git/dockerfiles/kairos-strix-halo-ubuntu/firmware
curl -fsSL -o LICENSE.amdgpu \
  https://gitlab.com/kernel-firmware/linux-firmware/-/raw/main/LICENSE.amdgpu
head -3 LICENSE.amdgpu
```
Expected: the first lines of the AMD license
(`Copyright (C) 2009-...  Advanced Micro Devices, Inc. All rights reserved.`).
If the URL fails, take the amdgpu section from strix's
`/usr/share/doc/linux-firmware/copyright` instead.

- [ ] **Step 5: Write `firmware/README.md`**

```markdown
# Pinned gfx1151 MES firmware

These are the MES blobs that strix (Radeon 8060S, gfx1151) ran without
problems before this image. The kernel reports them as `MES 0x80` and
`MES_KIQ 0x6f`. They come from noble
`linux-firmware 20240318.git3b128b60-0ubuntu2.21`.

The image installs them in `/lib/firmware/updates/amdgpu/`. The kernel loads
firmware from `updates/` before `/lib/firmware/amdgpu/`, so noble firmware
updates cannot replace them.

Why they are pinned:

- The MES version is not in the file (the header field is `0`). You only see
  the version after the kernel loads the blob.
- Newer gfx1151 MES blobs have had their own bugs: 0x83 causes page faults
  (ROCm/ROCm#5724) and 0x86 causes silent hangs (ROCm/ROCm#6165).

To change a blob, boot it on strix, read the version with
`sudo cat /sys/kernel/debug/dri/*/amdgpu_firmware_info | grep MES`, run a
load test, and then update `SHA256SUMS` and the pins in `../check-image.sh`.

License: `LICENSE.amdgpu`.
```

- [ ] **Step 6: Commit**

```bash
cd ~/_git/dockerfiles
git add kairos-strix-halo-ubuntu/firmware
git commit -F - <<'EOF'
feat(kairos-strix-halo-ubuntu): vendor the gfx1151 MES firmware

Pin the MES 0x80 and MES_KIQ 0x6f blobs that strix runs today. The
MES version is not stored in the file, and newer gfx1151 blobs (0x83,
0x86) have known hangs, so the image ships these exact files.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 2: Image check script and its tests

**Files:**
- Create: `kairos-strix-halo-ubuntu/check-image.sh`
- Create: `kairos-strix-halo-ubuntu/tests/check-image_test.sh`

**Interfaces:**
- Consumes: `kairos-strix-halo-ubuntu/firmware/*.zst` from Task 1 (the tests
  build fake roots with them).
- Produces: `check-image.sh [ROOT]`. `ROOT` defaults to `/`. The environment
  variable `LSINITRD` names the command that lists the initramfs (default
  `lsinitrd`). The script prints `check-image: OK (<kver>)` and exits 0 when
  every check passes. Otherwise it prints `check-image: FAIL: <reason>` on
  stderr and exits 1. Task 4 runs it in the Dockerfile as
  `/usr/local/sbin/strix-halo-check-image /`.

- [ ] **Step 1: Write the failing tests**

Create `kairos-strix-halo-ubuntu/tests/check-image_test.sh`:

```sh
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
```

Run: `chmod +x kairos-strix-halo-ubuntu/tests/check-image_test.sh`

- [ ] **Step 2: Run the tests and see them fail**

Run: `sh kairos-strix-halo-ubuntu/tests/check-image_test.sh`
Expected: every case prints `FAIL` (the script `check-image.sh` does not
exist), then `14 test(s) failed`, and the exit code is 1.

- [ ] **Step 3: Write `check-image.sh`**

Create `kairos-strix-halo-ubuntu/check-image.sh`:

```sh
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

# 5. If amdgpu loads from the initramfs, the pinned firmware must be there
# too, or early boot loads the stock blob.
if [ -f "$root/boot/initrd" ]; then
    listing=$("$lsinitrd" "$root/boot/initrd" 2>/dev/null) ||
        fail "cannot list the initramfs with '$lsinitrd'"
    if printf '%s\n' "$listing" | grep -q '/amdgpu\.ko'; then
        for name in gc_11_5_1_mes_2.bin.zst gc_11_5_1_mes1.bin.zst; do
            printf '%s\n' "$listing" | grep -Fq "firmware/updates/amdgpu/$name" ||
                fail "initramfs has amdgpu.ko but not updates/amdgpu/$name"
        done
    fi
fi

echo "check-image: OK ($kver)"
```

Run: `chmod +x kairos-strix-halo-ubuntu/check-image.sh`

Note for the fake-`lsinitrd` tests: `lsinitrd` normally prints long `ls -l`
style lines. The checks match substrings (`/amdgpu.ko`,
`firmware/updates/amdgpu/<name>`), so both the fake lines and the real output
match.

- [ ] **Step 4: Run the tests and see them pass**

Run: `sh kairos-strix-halo-ubuntu/tests/check-image_test.sh`
Expected: 14 lines that start with `ok`, then `all tests passed`, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd ~/_git/dockerfiles
git add kairos-strix-halo-ubuntu/check-image.sh kairos-strix-halo-ubuntu/tests/check-image_test.sh
git commit -F - <<'EOF'
feat(kairos-strix-halo-ubuntu): add the image check script

The build must fail if the image does not boot an OEM kernel with the
gfx1151 CWSR/VGPR fix, or if the pinned MES firmware is not in place
(also in the initramfs). The script takes a root directory so the
tests can run it against fake roots.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
```

---

### Task 3: Copy the Wi-Fi and time-sync config

**Files:**
- Create: `kairos-strix-halo-ubuntu/time-sync.yaml` (copy of `kairos-wifi-ubuntu/time-sync.yaml`)
- Create: `kairos-strix-halo-ubuntu/custom_bind_mounts.yaml` (copy of `kairos-wifi-ubuntu/custom_bind_mounts.yaml`)

**Interfaces:**
- Produces: the two files that Task 4's Dockerfile copies to `/system/oem/`.

- [ ] **Step 1: Copy the files**

```bash
cd ~/_git/dockerfiles
cp kairos-wifi-ubuntu/time-sync.yaml kairos-wifi-ubuntu/custom_bind_mounts.yaml kairos-strix-halo-ubuntu/
```

- [ ] **Step 2: Verify they are identical copies**

Run:
```bash
cmp kairos-wifi-ubuntu/time-sync.yaml kairos-strix-halo-ubuntu/time-sync.yaml &&
cmp kairos-wifi-ubuntu/custom_bind_mounts.yaml kairos-strix-halo-ubuntu/custom_bind_mounts.yaml &&
echo same
```
Expected: `same`.

- [ ] **Step 3: Record the service name for Task 6**

Run: `grep -n -e 'name:' -e '\.service' -e '\.timer' kairos-strix-halo-ubuntu/time-sync.yaml`
Write the systemd unit name(s) you find in the Task 6 step 3 notes. Task 6
compares them with `/oem/92_time-sync.yaml` on strix to find duplicates.

Do not commit yet. Task 4 commits these files together with the Dockerfile
that uses them.

---

### Task 4: Dockerfile, local build, and README

**Files:**
- Create: `kairos-strix-halo-ubuntu/Dockerfile`
- Modify: `README.md` (Images table after line 16; new section after the
  `### Kairos WiFi (Ubuntu)` section, before `### OpenStaManager`)

**Interfaces:**
- Consumes: `firmware/` (Task 1), `check-image.sh` (Task 2), the YAML files
  (Task 3).
- Produces: a local image `kairos-strix-halo-ubuntu:dev`. The CI image name
  is `ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu`.

- [ ] **Step 1: Check disk space**

Run: `df -h / | tail -1`
Expected: at least 15G available. If not, STOP and ask the owner to free
space. Do not delete files you did not create. The big items on 2026-09-29
were `/tmp/tev1-4b-e2e`, `/tmp/venv_nemo` and `/tmp/rc_strix_inf*.log`, all
from other work.

- [ ] **Step 2: Write the Dockerfile**

Create `kairos-strix-halo-ubuntu/Dockerfile`:

```dockerfile
# syntax=docker/dockerfile:1
#
# Kairos Ubuntu OS image for the AMD Strix Halo box (Ryzen AI Max+ 395,
# Radeon 8060S, gfx1151), with WiFi.
#
# This is kairos-wifi-ubuntu with one real change: the kernel. On the stock
# noble kernel the GPU hangs under ROCm load ("MES failed to respond to
# msg=REMOVE_QUEUE", then a GPU reset that kills every GPU process), because
# the gfx1151 compute wave save/restore (CWSR) area is sized too small. The
# fix is two amdkfd commits ("bump minimum vgpr size for gfx1151" and
# "Export the cwsr_size and ctl_stack_size to userspace"). They are in the
# Ubuntu OEM kernels, so this image installs linux-image-oem-24.04 in place of
# the kernel kairos-init picks. Without the fix, the only workaround is
# amdgpu.cwsr_enable=0.
#
# The gfx1151 MES firmware is pinned to the blobs strix ran without problems
# (MES 0x80): see firmware/README.md. check-image.sh fails the build if the
# kernel or firmware is wrong.

FROM quay.io/kairos/kairos-init:v4.3.0 AS kairos-init

FROM ubuntu:24.04 AS base-kairos
ARG VERSION=v4.3.0
ARG K8S_PROVIDER=k3s
ARG K8S_VERSION=v1.34.11+k3s1
ENV DEBIAN_FRONTEND=noninteractive

# Pinned MES firmware. It must be in place before the init stage, because
# the init stage builds the initramfs, and amdgpu can load from it.
COPY firmware/gc_11_5_1_mes_2.bin.zst firmware/gc_11_5_1_mes1.bin.zst /lib/firmware/updates/amdgpu/
COPY firmware/LICENSE.amdgpu firmware/README.md /usr/share/doc/strix-halo-mes-firmware/

# Install stage without its kernel, then the OEM kernel, then the init stage
# (which builds the initramfs for the only kernel in the image).
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -s install -p "${K8S_PROVIDER}" \
      --provider-k3s-version "${K8S_VERSION}" --version "${VERSION}" \
      --skip-step installKernel && \
    apt-get update && \
    apt-get install -y --no-install-recommends linux-image-oem-24.04 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    /kairos-init -l debug -s init -p "${K8S_PROVIDER}" \
      --provider-k3s-version "${K8S_VERSION}" --version "${VERSION}"

FROM base-kairos

ENV DEBIAN_FRONTEND=noninteractive

# WiFi userspace, the same as kairos-wifi-ubuntu: see that Dockerfile for why
# it is --no-install-recommends and why wired networking is left alone.
RUN apt-get update && apt-get install -y --no-install-recommends \
      network-manager wpasupplicant iw && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# One-shot NTP clock step for a WiFi-primary box (see the file).
COPY time-sync.yaml /system/oem/time-sync.yaml

# Persist saved network config across upgrades.
COPY custom_bind_mounts.yaml /system/oem/custom_bind_mounts.yaml

# Fail the build if the kernel or the MES firmware is wrong.
COPY check-image.sh /usr/local/sbin/strix-halo-check-image
RUN /usr/local/sbin/strix-halo-check-image /
```

- [ ] **Step 3: Build it**

Run (from `~/_git/dockerfiles`):
```bash
DOCKER_BUILDKIT=1 docker build -t kairos-strix-halo-ubuntu:dev kairos-strix-halo-ubuntu 2>&1 | tail -40
```
Expected: the build ends with `check-image: OK (6.17.0-1032-oem)` (or a newer
`-oem` version) and `naming to docker.io/library/kairos-strix-halo-ubuntu:dev`.

If it fails, read the message:
- `expected exactly one kernel`: something pulled in a second kernel. Run
  `docker run --rm --entrypoint sh <last good layer> -c 'dpkg -l "linux-image*" "linux-modules*"'`,
  find the package that pulled it in, and purge it before the init stage.
- `/boot/vmlinuz not found` or `is not vmlinuz-<kver>`: the kairos-init
  `kernel` step did not link the OEM kernel. Check where `/boot/vmlinuz` is
  created by running `/kairos-init steps-info` in the kairos-init image, and
  report it before you change anything.
- `initramfs has amdgpu.ko but not updates/...`: dracut did not include
  `updates/`. Add `install_items+=" /lib/firmware/updates/amdgpu/gc_11_5_1_mes_2.bin.zst /lib/firmware/updates/amdgpu/gc_11_5_1_mes1.bin.zst "`
  in `/etc/dracut.conf.d/50-strix-halo-mes.conf` before the init stage, and
  rebuild.

- [ ] **Step 4: Check the image contents**

Run:
```bash
docker run --rm --entrypoint sh kairos-strix-halo-ubuntu:dev -c '
  ls /lib/modules; ls -l /boot;
  ls -l /lib/firmware/updates/amdgpu;
  lsinitrd /boot/initrd | grep -e "/amdgpu\.ko" -e "updates/amdgpu" ;
  cat /etc/kairos-release | grep -e KAIROS_VERSION -e KAIROS_FLAVOR_RELEASE;
  ls /system/oem | grep -e time-sync -e custom_bind_mounts'
```
Expected: one `*-oem` directory in `/lib/modules`; `/boot/vmlinuz` and
`/boot/initrd` present; both pinned blobs in `updates/amdgpu`; the `lsinitrd`
lines either show nothing for amdgpu, or show amdgpu together with both
`updates/amdgpu` blobs; `KAIROS_VERSION="v4.3.0"`,
`KAIROS_FLAVOR_RELEASE="24.04"`; `time-sync.yaml` and
`custom_bind_mounts.yaml`.

- [ ] **Step 5: Check that the owner's release-pin check passes for the new Dockerfile**

Run:
```bash
cd ~/_git/dockerfiles
f=kairos-strix-halo-ubuntu/Dockerfile
grep -Fq 'FROM quay.io/kairos/kairos-init:v4.3.0 AS kairos-init' $f &&
grep -Fq '/kairos-init -l debug -s install' $f &&
grep -Fq '/kairos-init -l debug -s init' $f && echo pins-ok
```
Expected: `pins-ok`.

- [ ] **Step 6: Update README.md**

In the Images table, after the `kairos-wifi-ubuntu` row (line 16), add:

```markdown
| `ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu` | Kairos Ubuntu amd64 image for AMD Strix Halo (gfx1151), with WiFi | [Kairos Strix Halo (Ubuntu)](#kairos-strix-halo-ubuntu) |
```

After the `### Kairos WiFi (Ubuntu)` section, before `### OpenStaManager`, add:

````markdown
### Kairos Strix Halo (Ubuntu)

`kairos-wifi-ubuntu` for the AMD Ryzen AI Max+ 395 (Radeon 8060S, gfx1151),
with two changes:

- **The kernel is `linux-image-oem-24.04`** (6.17 OEM), not the kernel
  kairos-init installs. On the stock noble kernel the GPU hangs under ROCm
  load (`MES failed to respond to msg=REMOVE_QUEUE`, then a GPU reset). The
  cause is a gfx1151 CWSR save area that is too small. The OEM kernel has the
  fix, so this image does not need `amdgpu.cwsr_enable=0`.
- **The gfx1151 MES firmware is pinned** to the MES 0x80 blobs in
  `/lib/firmware/updates/amdgpu/`. Newer gfx1151 MES blobs have had their
  own hangs. See [`kairos-strix-halo-ubuntu/firmware/README.md`](kairos-strix-halo-ubuntu/firmware/README.md).

The build runs `check-image.sh` and fails if the kernel does not have the
fix or the pinned firmware is missing. To test the check script:

```bash
sh kairos-strix-halo-ubuntu/tests/check-image_test.sh
```

Upgrade a running Kairos node:

```bash
kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu:master
```

After the reboot, the fix is active if the GPU node exports the CWSR sizes:

```bash
grep -E 'cwsr_size|ctl_stack_size' /sys/class/kfd/kfd/topology/nodes/*/properties
```
````

- [ ] **Step 7: Commit**

```bash
cd ~/_git/dockerfiles
git add kairos-strix-halo-ubuntu/Dockerfile kairos-strix-halo-ubuntu/time-sync.yaml \
  kairos-strix-halo-ubuntu/custom_bind_mounts.yaml README.md
git commit -F - <<'EOF'
feat(kairos-strix-halo-ubuntu): add Kairos image for AMD Strix Halo

Build kairos-wifi-ubuntu with linux-image-oem-24.04 in place of the
kernel kairos-init installs. The OEM kernel has the gfx1151 CWSR/VGPR
fix, so strix no longer needs amdgpu.cwsr_enable=0 to stop MES hangs
under ROCm load. The build runs check-image.sh.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git status -s
```
Expected: the commit succeeds, and `git status -s` still shows only
` M .github/workflows/images.yaml` and `?? tests/` (the owner's work).

---

### Task 5: Publish through CI (owner step)

**Files:**
- Modify (by the owner, not by the executor): `.github/workflows/images.yaml`
- Modify (by the owner, optional): `tests/check-kairos-release.sh`

- [ ] **Step 1: Give the owner the exact changes**

Tell the owner to add this matrix entry after the `kairos-wifi-ubuntu` entry
in `.github/workflows/images.yaml` (after line 63):

```yaml
              - name: kairos-strix-halo-ubuntu
                context: ./kairos-strix-halo-ubuntu
                dockerfile: ./kairos-strix-halo-ubuntu/Dockerfile
                image: ghcr.io/${{ github.repository }}/kairos-strix-halo-ubuntu
                platform: linux/amd64
                runs-on: ubuntu-latest
```

And, optionally, to add `kairos-strix-halo-ubuntu/Dockerfile` to the
`kairos_dockerfiles` list in `tests/check-kairos-release.sh`.

- [ ] **Step 2: Push and wait for the image**

After the owner commits the workflow change, push `master`:
`git -C ~/_git/dockerfiles push origin master`. Then watch the run:
`gh run list -R mudler/dockerfiles -L 3` and `gh run watch <id> -R mudler/dockerfiles`.
Expected: the `kairos-strix-halo-ubuntu` job succeeds, and its log contains
`check-image: OK`.

- [ ] **Step 3: Check the published image**

Run: `docker manifest inspect ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu:master | head -5`
Expected: a manifest for `linux/amd64`. If `master` is not the tag the
workflow pushes, use the tag from the job log in Task 6.

---

### Task 6: Upgrade strix (the workaround stays on)

**Files:** none (operations on strix).

This task reboots strix. notary, auth, the LocalAI frontend, the Cloudflare
tunnel and rc are down for a few minutes. Get the owner's go-ahead first.

- [ ] **Step 1: Record the state before the upgrade**

Run:
```bash
ssh mudler@strix.casa 'uname -r; cat /proc/cmdline; grep -E "^(KAIROS_VERSION|KAIROS_FLAVOR_RELEASE)" /etc/kairos-release;
  cat /sys/class/drm/card*/device/mem_info_vram_total /sys/class/drm/card*/device/mem_info_gtt_total; grep MemTotal /proc/meminfo;
  sudo -n grub2-editenv /oem/grubenv list; sudo -n journalctl -k -b --no-pager | grep -c "GPU reset begin"'
```
Expected: `6.14.0-36-generic`, `amdgpu.cwsr_enable=0` in the cmdline,
`KAIROS_VERSION="v3.5.9"`, VRAM `103079215104`, GTT about `16635248640`,
MemTotal about `32490724 kB`, `extra_cmdline=amdgpu.cwsr_enable=0`. Keep this
output for the comparison in step 3.

- [ ] **Step 2: Upgrade and reboot**

Run:
```bash
ssh mudler@strix.casa 'sudo -n kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu:master' 2>&1 | tail -20
ssh mudler@strix.casa 'sudo -n grub2-editenv /oem/grubenv list; (sudo -n systemctl reboot &); exit 0'
```
Expected: the upgrade finishes without an error, and `extra_cmdline` is still
set. Then wait until SSH answers:
```bash
until ssh -o ConnectTimeout=5 -o BatchMode=yes mudler@strix.casa true 2>/dev/null; do sleep 10; done
```

If strix does not come back within 10 minutes, it is on Wi-Fi with no
console. Ask the owner to pick the fallback (passive) entry in the GRUB menu
on the box.

- [ ] **Step 3: Check the new image (spec success criteria 1, 2, 5)**

Run:
```bash
ssh mudler@strix.casa '
  uname -r; cat /proc/cmdline; grep -E "^KAIROS_VERSION" /etc/kairos-release
  grep -H -E "cwsr_size|ctl_stack_size" /sys/class/kfd/kfd/topology/nodes/*/properties
  cat /sys/module/amdgpu/parameters/cwsr_enable
  sudo -n cat /sys/kernel/debug/dri/*/amdgpu_firmware_info 2>/dev/null | grep -e "^MES"
  cat /sys/class/drm/card*/device/mem_info_vram_total /sys/class/drm/card*/device/mem_info_gtt_total; grep MemTotal /proc/meminfo
  nmcli -t -f DEVICE,STATE dev | grep wlp; timedatectl | grep -i synchronized
  mount | grep -i -e cifs -e smb | head -2; zramctl
  sudo -n k3s kubectl get pods -A --no-headers | grep -v -e Running -e Completed
  sudo -n k3s kubectl -n flux-system get kustomizations --no-headers'
curl -s -m 15 -o /dev/null -w "notary %{http_code}\n" https://notary.nervhq.ai/api/auth/status
```
Expected:
- `uname -r` is the `-oem` kernel, and the cmdline still has `amdgpu.cwsr_enable=0`.
- `KAIROS_VERSION="v4.3.0"`.
- The GPU node (`nodes/1`) shows `cwsr_size` and `ctl_stack_size`.
- `cwsr_enable` is `0` (the workaround is still on).
- `MES feature version: 1, firmware version: 0x00000080` (the pinned blob).
- VRAM, GTT and MemTotal match step 1.
- Wi-Fi is `connected`, the clock is synchronized, the NAS is mounted, and zram exists.
- No pods outside Running/Completed after about 5 minutes, and both Kustomizations are `True`.
- notary returns `200`.

Time-sync check: run
`ssh mudler@strix.casa 'sudo -n systemctl list-units --all | grep -i -e sntp -e time-step -e clock'`
and compare with the unit names from Task 3 step 3 and with
`sudo -n grep -n -e "\.service" -e "\.timer" /oem/92_time-sync.yaml`. If both
files install a unit that runs, remove `/oem/92_time-sync.yaml`
(`sudo -n rm /oem/92_time-sync.yaml`), because the image now provides it. Then
reboot once more and check the clock again.

If a check fails, stop here and report it. The rollback is the fallback GRUB
entry, or
`sudo kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-wifi-ubuntu:<previous tag>`.

---

### Task 7: Remove the workaround and soak

**Files:**
- Modify: `~/_git/infra-flux-kube/docs/services.md` (strix section, the memory note near line 170)

- [ ] **Step 1: Remove `extra_cmdline` and reboot**

Run:
```bash
ssh mudler@strix.casa 'sudo -n grub2-editenv /oem/grubenv unset extra_cmdline; sudo -n grub2-editenv /oem/grubenv list; (sudo -n systemctl reboot &); exit 0'
until ssh -o ConnectTimeout=5 -o BatchMode=yes mudler@strix.casa true 2>/dev/null; do sleep 10; done
ssh mudler@strix.casa 'cat /proc/cmdline; cat /sys/module/amdgpu/parameters/cwsr_enable'
```
Expected: the grubenv list is empty, the cmdline has no `cwsr_enable`, and the
parameter reads `1` (spec criterion 3).

- [ ] **Step 2: Soak for 24 hours**

Leave strix under normal load for 24 hours. Then run:
```bash
ssh mudler@strix.casa '
  sudo -n journalctl -k -b --no-pager | grep -c -e "MES failed to respond" -e "GPU reset begin"
  sudo -n k3s kubectl -n local-ai logs deploy/local-ai-worker --since=24h | grep -c "GPU Hang"
  uptime'
```
Expected: `0`, `0`, and an uptime of more than 24 hours (spec criterion 4).
To compare: before the change strix had 80 resets in 6 days.

If there is a reset, put the workaround back and report:
```bash
ssh mudler@strix.casa 'sudo -n grub2-editenv /oem/grubenv set extra_cmdline="amdgpu.cwsr_enable=0"; (sudo -n systemctl reboot &); exit 0'
```

- [ ] **Step 3: Update `docs/services.md` in infra-flux-kube**

In `~/_git/infra-flux-kube/docs/services.md`, in the strix section:
- Line 139: change "installed from `ghcr.io/mudler/dockerfiles/kairos-wifi-ubuntu`"
  to "runs `ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu` (OEM 6.17
  kernel with the gfx1151 CWSR fix, pinned MES 0x80 firmware; upgraded
  <date>)".
- In the memory note (the paragraph that starts "The iGPU's memory is a
  firmware carve-out"), add one sentence: "The GPU MES hangs of September 2026
  (`MES failed to respond to msg=REMOVE_QUEUE`) were a gfx1151 CWSR sizing
  bug in the stock 6.14 kernel, fixed by the OEM kernel.
  `amdgpu.cwsr_enable=0` is not set."

Then:
```bash
cd ~/_git/infra-flux-kube
git add docs/services.md
git commit -F - <<'EOF'
docs(strix): record the kairos-strix-halo-ubuntu image

strix now runs the OEM 6.17 kernel with the gfx1151 CWSR fix and no
longer needs amdgpu.cwsr_enable=0.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
git pull --rebase -q origin main && git push -q origin main
```
