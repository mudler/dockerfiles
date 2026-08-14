# syntax=docker/dockerfile:1
#
# Kairos NVIDIA Jetson AGX Orin OS image with Docker + k3s.
#
# Built with kairos-init rather than FROM a published
# `quay.io/kairos/ubuntu:22.04-...-nvidia-jetson-agx-orin-*` base, to match
# kairos-thor-docker and kairos-dgx-spark-docker. Those two build this way out of
# necessity (no published base exists for their boards yet); doing the same here
# means all three Jetson/NVIDIA boards are assembled by one mechanism, with the
# Kubernetes provider selected by the same K8S_PROVIDER/K8S_VERSION args instead
# of by picking a different upstream image variant.
#
# k3s is the point of this image: it lets the LocalAI worker run here as a
# Flux-managed k8s Deployment (the `orin` cluster) like it does on the Thor and
# the DGX Spark, instead of the docker-compose worker this board used before.
#
# Base is ubuntu:22.04, not 24.04 as on the other two boards: the AGX Orin runs
# L4T r36.x (JetPack 6), whose packages are Jammy-built.
#
# k3s state needs no custom_bind_mounts.yaml entry — the Kubernetes provider's
# own /system/oem/00_rootfs.yaml adds /var/lib/rancher to PERSISTENT_STATE_PATHS,
# and /etc/rancher + /var/lib/kubelet come with it. Verified on the Thor, where
# all three are bind-mounted onto COS_PERSISTENT while its custom_bind_mounts.yaml
# lists only /var/lib/docker and /etc/netplan.

# --- Stage 1: build kairos-init ----------------------------------------------
FROM golang:1.26 AS kairos-init
ARG KAIROS_INIT_REPO=https://github.com/kairos-io/kairos-init
ARG KAIROS_INIT_REF=main
RUN apt-get update && apt-get install -y --no-install-recommends \
      git make file ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /src
RUN git clone --depth 1 --branch "${KAIROS_INIT_REF}" "${KAIROS_INIT_REPO}" .
# Fetch the embedded binaries (immucore, kairos-agent, ...) uncompressed (no UPX),
# then build the kairos-init binary with version metadata.
RUN SKIP_UPX=1 make all
RUN CGO_ENABLED=0 go build -o /kairos-init --ldflags \
      "-w -s -X github.com/kairos-io/kairos-init/pkg/values.version=$(git describe --tags --always --dirty) -X github.com/kairos-io/kairos-init/pkg/values.gitCommit=$(git rev-parse --short HEAD)" .

# --- Stage 2: assemble the Kairos AGX Orin OS rootfs --------------------------
FROM ubuntu:22.04 AS orin-kairos
ARG VERSION=v0.0.1
# Kubernetes provider baked in via kairos-init (-p installs the distro + the
# kairos provider-kairos plugin that bootstraps it). Default k3s; set empty to
# build a plain OS image, or pin K8S_VERSION for a specific k3s release.
ARG K8S_PROVIDER=k3s
ARG K8S_VERSION=
ENV DEBIAN_FRONTEND=noninteractive
# kairos-init is bind-mounted (not copied) so the build tool never lands in the
# final OS image. `install` lays down the L4T + Kairos packages for the AGX Orin
# model; `init` finalises the image (initrd, services, /system/oem configs).
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    P=""; V=""; \
    if [ -n "${K8S_PROVIDER}" ]; then P="-p ${K8S_PROVIDER}"; \
      [ -n "${K8S_VERSION}" ] && V="--provider-${K8S_PROVIDER}-version ${K8S_VERSION}"; fi; \
    /kairos-init -l debug -s install -m nvidia-jetson-agx-orin ${P} ${V} --version "${VERSION}" && \
    /kairos-init -l debug -s init    -m nvidia-jetson-agx-orin ${P} ${V} --version "${VERSION}"

# --- Stage 3: Docker + NVIDIA container runtime + tooling ---------------------
FROM orin-kairos
ENV DEBIAN_FRONTEND=noninteractive

# Drop the resurrected stock L4T apt source list before anything runs apt.
#
# kairos-init deliberately deletes /etc/apt/sources.list.d/nvidia-l4t-apt-source.list
# and writes its own /etc/apt/sources.list.d/nvidia-drivers.list holding
# jetson/common and jetson/t234, both signed by /usr/share/keyrings/jetson-ota.gpg.
# An L4T package installed later in the same stage puts the stock file back, and
# the restored copy is the flash-time template: its SOC entry is still the literal
# placeholder, never substituted for this board.
#
# That single resurrected file caused every failure seen so far. Unqualified
# duplicates of jetson/common made apt refuse to read the whole source list
# ("Conflicting values set for option Signed-By ... The list of sources could not
# be read", exit 100); with that resolved, the placeholder entry then 404'd
# ("The repository 'https://repo.download.nvidia.com/jetson/<SOC> r36.4 Release'
# does not have a Release file"), which is equally fatal to apt-get update.
#
# Removing it restores exactly what kairos-init intended. Nothing is lost: the
# AGX Orin currently in the fleet, running the previous published-base image,
# carries only jetson/common and jetson/t234 — the same two repos
# nvidia-drivers.list provides, and no jetson/ffmpeg.
#
# The greps are deliberate: this cannot be reproduced off an arm64 L4T rootfs, so
# if the layout ever changes the build log shows the before/after state rather
# than failing blind.
RUN set -eux; \
    echo "--- jetson apt sources before ---"; \
    grep -rn "repo.download.nvidia.com" /etc/apt/ || true; \
    rm -f /etc/apt/sources.list.d/nvidia-l4t-apt-source.list; \
    echo "--- after dropping the stock L4T list ---"; \
    grep -rn "repo.download.nvidia.com" /etc/apt/ || true; \
    apt-get update

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    vim \
    htop \
    tmux && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install docker
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install NVIDIA Container Toolkit.
# `nvidia-ctk runtime configure --runtime=docker` wires the nvidia runtime into
# docker; k3s needs no equivalent step, as it auto-detects
# /usr/bin/nvidia-container-runtime at startup and creates the `nvidia`
# RuntimeClass itself (which is what the LocalAI worker Deployment requests).
RUN curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
        && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
     tee /etc/apt/sources.list.d/nvidia-container-toolkit.list && apt-get update && apt-get install -y nvidia-container-toolkit && nvidia-ctk runtime configure --runtime=docker && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY custom_bind_mounts.yaml /system/oem/custom_bind_mounts.yaml

RUN apt-get update && apt-get install -y git python3-pip && python3 -m pip install --upgrade pip && python3 -m pip install jetson-stats
