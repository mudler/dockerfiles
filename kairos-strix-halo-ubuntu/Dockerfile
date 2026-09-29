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
