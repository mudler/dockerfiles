# kairos-strix-halo-ubuntu: Kairos image with a gfx1151-fixed kernel

Date: 2026-09-29
Status: design, awaiting review

## Problem

`strix` (AMD Ryzen AI Max+ 395, Radeon 8060S, gfx1151) runs an older build of
`kairos-wifi-ubuntu` (Kairos v3.5.9, kernel `6.14.0-36-generic`, MES firmware
0x80). Under ROCm llama.cpp load its GPU hangs and resets: 80 resets in the 6
days up to 2026-09-29. 72 of them start with the same kernel message:

```
amdgpu: MES failed to respond to msg=REMOVE_QUEUE
amdgpu: MES might be in unrecoverable state, issue a GPU reset
```

The reset kills every GPU process. The LocalAI backend exits with
`HW Exception by GPU node-1 ... reason :GPU Hang`, the frontend evicts the
model, and requests fail.

Root cause: the gfx1151 compute wave save/restore (CWSR) area is sized too
small. The kernel fix is two commits:

- `drm/amdkfd: bump minimum vgpr size for gfx1151` (cf326449637a5)
- `drm/amdkfd: Export the cwsr_size and ctl_stack_size to userspace`

They are in mainline 6.18.4+, the Ubuntu OEM 6.14 and 6.17 kernels, and the
6.17 HWE kernel. `6.14.0-36-generic` does not have them. A running kernel with
the fix exports `cwsr_size` and `ctl_stack_size` in
`/sys/class/kfd/kfd/topology/nodes/*/properties`, and strix exports neither.

The MES "LR compute workaround" (MES firmware >= 0x7f plus
`drm/amdgpu: Enable MES lr_compute_wa by default`) was an earlier attempt at a
fix. Upstream removed it in February 2026 because the VGPR fix was the real one.

Current mitigation: `amdgpu.cwsr_enable=0` is set on strix through
`extra_cmdline` in `/oem/grubenv` (applied 2026-09-29).

References:

- ROCm/ROCm#5590: same hardware, MES 0x80, same messages; workaround `cwsr_enable=0`
- ROCm/ROCm#5724: MES 0x83 causes page faults and GPU hangs on gfx1151
- ROCm/ROCm#6165: silent hard hang with MES 0x86 on gfx1151
- Ubuntu kernel-team SRU "GFX1151 kernel fixes", January 2026
- Launchpad #2129150: MES firmware >= 0x7f for the LR compute workaround

## Goal

Build an OS image for strix whose kernel has the gfx1151 CWSR fix, so strix
runs with the default `amdgpu.cwsr_enable=1` and has no MES hangs.

Success criteria:

1. On strix, `uname -r` shows the OEM kernel from the image.
2. `cwsr_size` and `ctl_stack_size` appear in the kfd topology of the GPU node.
3. `/sys/module/amdgpu/parameters/cwsr_enable` reads `1`, and `/oem/grubenv`
   has no `extra_cmdline`.
4. During 24 hours of normal LLM load, `journalctl -k` shows no
   `MES failed to respond` and no `GPU reset`, and no LocalAI backend exits
   with `GPU Hang`.
5. The rest of strix still works after the upgrade: Wi-Fi, time sync, NAS
   mount, zram, all pods Running, and `https://notary.nervhq.ai/api/auth/status`
   returns 200.

## Non-goals

- Changing `kairos-wifi-ubuntu`. Other boxes that use it keep their kernel.
- A newer `linux-firmware` than noble ships. The fix is in the kernel. Newer
  MES blobs (0x83, 0x86) have had their own gfx1151 bugs.
- Ubuntu 26.04 or a mainline kernel.
- Baking `amdgpu.cwsr_enable=0` into the image.

## Design

### Image layout

New directory `kairos-strix-halo-ubuntu/`, separate from `kairos-wifi-ubuntu`:

| File | Content |
|---|---|
| `Dockerfile` | Based on `kairos-wifi-ubuntu/Dockerfile`, with the kernel steps below |
| `time-sync.yaml` | Copy of `kairos-wifi-ubuntu/time-sync.yaml` |
| `custom_bind_mounts.yaml` | Copy of `kairos-wifi-ubuntu/custom_bind_mounts.yaml` |

The image does not use `FROM kairos-wifi-ubuntu`: two images that depend on
each other would have to build in order in CI. The two copied YAML files are
the cost of that choice.

The pins stay the same as `kairos-wifi-ubuntu`: `quay.io/kairos/kairos-init:v4.3.0`,
`ubuntu:24.04`, `VERSION=v4.3.0`, `K8S_PROVIDER=k3s`,
`K8S_VERSION=v1.34.11+k3s1`. If the existing "Check Kairos release pins" CI
step checks a list of images, add the new image to that list.

### Kernel

In the `base-kairos` stage:

1. Run `/kairos-init -s install --skip-step installKernel`, with the same
   provider and version flags as `kairos-wifi-ubuntu`.
2. Run `apt-get install -y linux-oem-24.04`.
3. Remove every kernel image, module and header package that is not the OEM
   kernel, so the image has exactly one `/boot/vmlinuz-*`. Kairos boots
   `/boot/vmlinuz`, so the kernel it boots must be the OEM one.
4. Run `/kairos-init -s init`, which builds the initramfs for the OEM kernel.

If `kairos-init` does not accept `--skip-step installKernel` in v4.3.0, use the
fallback: let it install its kernel, install `linux-oem-24.04`, remove the
kernel packages that are not the OEM kernel, and then run `init`. The build
checks below catch a wrong kernel in both cases.

The final stage is the same as in `kairos-wifi-ubuntu`: `network-manager`,
`wpasupplicant` and `iw` with `--no-install-recommends`, then the two
`/system/oem` YAML files.

### Build checks

A `RUN` step at the end of the Dockerfile. If a check fails, the build fails
and CI pushes nothing.

1. **Exactly one kernel.** `/lib/modules` has one directory, and its name
   contains `-oem`.
2. **The kernel has the fix.** The changelog of the installed kernel image
   package (`/usr/share/doc/linux-image-<ver>/changelog.Debian.gz`, or the
   linux-modules package if the image package has no changelog) contains
   `bump minimum vgpr size for gfx1151`. If the Ubuntu changelog does not
   list cherry-picked upstream commits by title, use a different check: the
   `amdgpu` module contains the `cwsr_size` sysfs attribute name
   (`modinfo -n amdgpu` gives the module file, and `strings` on the
   decompressed module finds the name).
3. **MES firmware is safe.** Read the version from
   `/lib/firmware/amdgpu/gc_11_5_1_mes_2.bin*` (decompress it if it is
   `.zst`). The version must be `>= 0x7f` and not `0x83`. The plan must say
   where in the file the version is and show that the check reads `0x80` from
   the firmware now on strix.

### Documentation

- `README.md`: add a `kairos-strix-halo-ubuntu` row to the Images table, and a
  `### Kairos Strix Halo (Ubuntu)` section after `### Kairos WiFi (Ubuntu)`.
  The section says why the image exists (gfx1151 CWSR fix), which kernel it
  ships, how to upgrade (`kairos-agent upgrade --source oci:...`), and that
  `amdgpu.cwsr_enable=0` is not needed with it.
- The Dockerfile header comment explains the kernel choice in the same style as
  the other Kairos Dockerfiles.

### CI

`.github/workflows/images.yaml` needs a matrix entry like the
`kairos-wifi-ubuntu` one:

```yaml
- name: kairos-strix-halo-ubuntu
  context: ./kairos-strix-halo-ubuntu
  dockerfile: ./kairos-strix-halo-ubuntu/Dockerfile
  image: ghcr.io/${{ github.repository }}/kairos-strix-halo-ubuntu
  platform: linux/amd64
  runs-on: ubuntu-latest
```

That file has uncommitted local changes that are not part of this work. The
implementation does not commit it. It gives the entry to the owner, who adds
it together with their own change.

## Rollout on strix

Change one thing at a time. Each step has a way back.

1. **Build and publish.** The image builds locally with its checks passing, and
   then CI publishes `ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu:master`.
2. **Upgrade with the workaround still set.** On strix, run
   `sudo kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-strix-halo-ubuntu:master`
   and reboot. `extra_cmdline=amdgpu.cwsr_enable=0` stays in `/oem/grubenv`,
   so this step changes only the OS image. The previous image stays on the
   passive partition as a boot fallback.
3. **Check the new image.** Check success criteria 1, 2 and 5. Also check that
   the image's `/system/oem/time-sync.yaml` and the hand-placed
   `/oem/92_time-sync.yaml` do not both install and start a clock-step service.
   If they conflict, remove `/oem/92_time-sync.yaml`, because the image now
   provides it.
4. **Remove the workaround.** Run
   `sudo grub2-editenv /oem/grubenv unset extra_cmdline` and reboot. Check
   criterion 3.
5. **Soak test.** Run 24 hours of normal load, then check criterion 4.
   - If it passes, go to step 6.
   - If it fails, run
     `sudo grub2-editenv /oem/grubenv set extra_cmdline="amdgpu.cwsr_enable=0"`,
     reboot, and investigate again. strix stays on the new image.
6. **Record it.** In `infra-flux-kube`, update `docs/services.md`: strix runs
   `kairos-strix-halo-ubuntu`, and the CWSR workaround is gone.

Rollback of the image: boot the passive (fallback) entry, or run
`kairos-agent upgrade` with the previous image reference.

## Risks

| Risk | Mitigation |
|---|---|
| `linux-oem-24.04` points to a kernel without the fix, or to a kernel that is too new | Build check 2 fails the build |
| A noble `linux-firmware` update ships MES 0x83 | Build check 3 fails the build. If this happens, the plan adds a known-good `gc_11_5_1_mes_2.bin` under `/lib/firmware/updates/amdgpu/` |
| The Kairos v3.5.9 to v4.3.0 upgrade breaks OEM config (`/oem/9x_*.yaml`) | Step 3 checks NAS, zram, time sync and Wi-Fi. The A/B fallback keeps the old image |
| The ROCm userspace in the LocalAI image reads the new `cwsr_size` and behaves differently | Criterion 4 covers this. The step 5 fallback restores the known-good state |
| The OEM kernel has a different amdgpu memory default (GTT/VRAM) | Step 3 compares `mem_info_vram_total`, `mem_info_gtt_total` and `MemTotal` with the values from before the upgrade (96GiB VRAM, about 15.5GiB GTT, about 31GiB RAM) |
