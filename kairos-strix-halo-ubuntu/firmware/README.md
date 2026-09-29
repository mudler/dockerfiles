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
