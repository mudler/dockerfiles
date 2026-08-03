# syntax=docker/dockerfile:1
#
# Kairos NVIDIA Jetson AGX Thor (T264) OS image with Docker.
#
# Unlike kairos-orin-docker, there is no published Kairos Thor base image to
# build FROM: Jetson Thor / L4T r39.2 support currently lives on a kairos-init
# branch, not in a Kairos release. So this Dockerfile builds kairos-init from
# that branch and uses it to assemble the Kairos Thor rootfs on top of a stock
# ubuntu:24.04 base, then layers Docker + the NVIDIA container runtime (same
# stack as kairos-orin-docker). Once Thor support is released, stages 1-2 can be
# collapsed into a single `FROM quay.io/kairos/ubuntu:24.04-...-thor-<rel>`.

# --- Stage 1: build kairos-init from the Thor enablement branch ---------------
FROM golang:1.26 AS kairos-init
ARG KAIROS_INIT_REPO=https://github.com/kairos-io/kairos-init
ARG KAIROS_INIT_REF=bump-thor-l4t-39.2
RUN apt-get update && apt-get install -y --no-install-recommends \
      git make file ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --branch "${KAIROS_INIT_REF}" "${KAIROS_INIT_REPO}" .
# Fetch the embedded binaries (immucore, kairos-agent, ...) uncompressed (no UPX),
# then build the kairos-init binary with version metadata.
RUN SKIP_UPX=1 make all
RUN CGO_ENABLED=0 go build -o /kairos-init --ldflags \
      "-w -s -X github.com/kairos-io/kairos-init/pkg/values.version=$(git describe --tags --always --dirty) -X github.com/kairos-io/kairos-init/pkg/values.gitCommit=$(git rev-parse --short HEAD)" .

# --- Stage 2: assemble the Kairos Thor OS rootfs ------------------------------
FROM ubuntu:24.04 AS thor-kairos
ARG VERSION=v0.0.1
ENV DEBIAN_FRONTEND=noninteractive
# kairos-init is bind-mounted (not copied) so the build tool never lands in the
# final OS image. `install` lays down the L4T + Kairos packages for the Thor
# model; `init` finalises the image (initrd, services, /system/oem configs -
# including the QSPI firmware check that fires on install *and* upgrade).
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -s install -m nvidia-jetson-thor --version "${VERSION}" && \
    /kairos-init -l debug -s init    -m nvidia-jetson-thor --version "${VERSION}"

# --- Stage 3: Docker + NVIDIA container runtime + tooling ---------------------
# (mirrors kairos-orin-docker)
FROM thor-kairos
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
      vim \
      htop \
      tmux && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Docker engine
RUN apt-get update && apt-get install -y \
      ca-certificates \
      curl \
      gnupg \
      lsb-release && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# NVIDIA Container Toolkit (wires the nvidia runtime into docker for GPU workloads)
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg && \
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
      > /etc/apt/sources.list.d/nvidia-container-toolkit.list && \
    apt-get update && apt-get install -y nvidia-container-toolkit && \
    nvidia-ctk runtime configure --runtime=docker && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# jetson-stats (jtop) for on-device monitoring. Non-fatal: T264 support may lag.
# Note: no `pip install --upgrade pip` - on Ubuntu 24.04 pip is distro-managed and
# cannot uninstall itself (RECORD file missing), which would fail the whole step.
RUN apt-get update && apt-get install -y git python3-pip && \
    (python3 -m pip install --break-system-packages jetson-stats || echo "jetson-stats install failed (non-fatal)") && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Persist /var/lib/docker on the Kairos persistent partition (rootfs is ephemeral)
COPY custom_bind_mounts.yaml /system/oem/custom_bind_mounts.yaml
