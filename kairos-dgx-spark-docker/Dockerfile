# syntax=docker/dockerfile:1
#
# Kairos NVIDIA DGX Spark (GB10 Grace-Blackwell) OS image, full stack.
#
# DGX Spark is a standard arm64 UEFI/SBSA machine (ACPI, GRUB, fwupd), so unlike
# the Jetson images there is no L4T/extlinux machinery. Kairos 4.3.0 includes
# DGX Spark support in kairos-init. Kairos v4 publishes Hadron OS artifacts
# only, so this image uses the supported BYOI path with Ubuntu 24.04. It then
# adds the NVIDIA container runtime and Docker.

# --- Stage 1: use the kairos-init release ------------------------------------
FROM quay.io/kairos/kairos-init:v4.3.0 AS kairos-init

# --- Stage 2: assemble the minimal Kairos DGX Spark rootfs --------------------
FROM ubuntu:24.04 AS dgx-kairos
ARG VERSION=v4.3.0
ARG K8S_PROVIDER=k3s
ARG K8S_VERSION=
ENV DEBIAN_FRONTEND=noninteractive
# `install` sets up the DGX/spark/CUDA repos and lays down the minimal package
# set (kernel, headless open driver, Mellanox networking, fwupd, spark cfg);
# `init` finalises the image (initrd, services, /system/oem configs).
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    P=""; V=""; \
    if [ -n "${K8S_PROVIDER}" ]; then P="-p ${K8S_PROVIDER}"; \
      [ -n "${K8S_VERSION}" ] && V="--provider-${K8S_PROVIDER}-version ${K8S_VERSION}"; fi; \
    /kairos-init -l debug -s install -m nvidia-dgx-spark ${P} ${V} --version "${VERSION}" && \
    /kairos-init -l debug -s init    -m nvidia-dgx-spark ${P} ${V} --version "${VERSION}"

# --- Stage 3: full stack — CUDA + NVIDIA container runtime + docker ------------
FROM dgx-kairos
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
      vim htop tmux && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# WiFi: userspace (NetworkManager) + firmware. The DGX's wifi is a MediaTek
# MT7925 (driver mt7925e), whose firmware ships in the monolithic linux-firmware
# package (verified on GB10 hardware: /lib/firmware/mediatek/mt7925/* is owned by
# stock noble linux-firmware - no NVIDIA wifi-fw PPA needed). There is no small
# standalone wifi-firmware package. Mellanox/ConnectX wired networking is covered
# by rdma-core + nvidia-mlnx-tools already.
RUN apt-get update && apt-get install -y \
      network-manager wireless-tools wpasupplicant linux-firmware && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Host CUDA toolkit is NOT installed by default: GPU workloads run in containers
# via the NVIDIA container runtime (below), where CUDA lives in the image. Baking
# the ~5GB dev toolkit into the host doubled the OS image for no node benefit.
#
# To install host CUDA (nvcc + dev libraries), uncomment the block below:
#
# RUN apt-get update && apt-get install -y ca-certificates curl gnupg && \
#     curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/3bf863cc.pub | \
#       gpg --dearmor -o /usr/share/keyrings/nvidia-cuda-sbsa.gpg && \
#     echo 'deb [signed-by=/usr/share/keyrings/nvidia-cuda-sbsa.gpg] https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/sbsa/ /' \
#       > /etc/apt/sources.list.d/nvidia-cuda-sbsa.list && \
#     apt-get update && apt-get install -y --no-install-recommends cuda-toolkit-12-6 && \
#     apt-get clean && rm -rf /var/lib/apt/lists/*

# Docker engine
RUN apt-get update && apt-get install -y \
      ca-certificates curl gnupg lsb-release && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y \
      docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# NVIDIA Container Toolkit (wires the nvidia runtime into docker for GPU workloads)
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list && \
    apt-get update && apt-get install -y nvidia-container-toolkit && \
    nvidia-ctk runtime configure --runtime=docker && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Persist /var/lib/docker + saved network config across upgrades (rootfs is ephemeral)
COPY custom_bind_mounts.yaml /system/oem/custom_bind_mounts.yaml
