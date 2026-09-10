# syntax=docker/dockerfile:1
#
# Kairos Ubuntu OS image for a standard amd64 machine, with WiFi.
#
# The sibling `kairos-wifi` image is openSUSE Leap based and carries only `iw` +
# `wpa_supplicant`. This one uses the Kairos 4.3.0 BYOI path to convert Ubuntu
# 24.04 into a standard amd64 image with k3s. It adds a NetworkManager-driven WiFi
# stack, so a laptop or NUC-class box can join a network with `nmtui` and keep
# that connection across OCI upgrades.
#
# `linux-firmware` is NOT installed here: the Kairos Ubuntu base already ships
# it (158 iwlwifi blobs, plus ath11k, mediatek, rtw and friends), so the
# wireless card's firmware is on the image already.

FROM quay.io/kairos/kairos-init:v4.3.0 AS kairos-init

FROM ubuntu:24.04 AS base-kairos
ARG VERSION=v4.3.0
ARG K8S_PROVIDER=k3s
ARG K8S_VERSION=v1.34.11+k3s1
ENV DEBIAN_FRONTEND=noninteractive
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -s install -p "${K8S_PROVIDER}" \
      --provider-k3s-version "${K8S_VERSION}" --version "${VERSION}" && \
    /kairos-init -l debug -s init -p "${K8S_PROVIDER}" \
      --provider-k3s-version "${K8S_VERSION}" --version "${VERSION}"

FROM base-kairos

ENV DEBIAN_FRONTEND=noninteractive

# WiFi userspace. --no-install-recommends keeps this to the 13 packages that
# matter; the recommends set drags in ModemManager, ppp/pptp, dnsmasq and tcl
# (44 packages) for dial-up and phone tethering this image has no use for.
#
# NetworkManager hard-depends on netplan.io on Ubuntu, so netplan arrives here
# even though the base has none - that is expected, and is why /etc/netplan is
# one of the persisted paths below.
#
# Wired networking is deliberately left alone. The base manages the network with
# systemd-networkd, and Kairos's own /system/oem/05_network.yaml rewrites
# /etc/systemd/network/20-dhcp*.network (Match en*/eth*) and runs `networkctl
# reload` on every boot; disabling networkd to hand everything to NetworkManager
# would break that stage. No config is needed to keep them apart: Ubuntu's
# NetworkManager ships /usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf
# with `unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma`,
# so it only ever touches wireless. Do NOT add an /etc/NetworkManager/conf.d
# override for this - a file sorting after that one replaces the whole key, and
# a naive `unmanaged-devices=type:ethernet` would hand NetworkManager every
# k3s-created interface (cni0, flannel.1, veths).
RUN apt-get update && apt-get install -y --no-install-recommends \
      network-manager wpasupplicant iw && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# One-shot NTP clock step. A WiFi-primary box cannot sync time on its own:
# NetworkManager owns the wireless device, so systemd-networkd treats it as
# unmanaged, timesyncd never sees the network come online and sends zero NTP
# packets. The clock stays at whatever the RTC held and every TLS handshake
# fails, which stops the box pulling any container image at all. See the file
# for the full diagnosis.
COPY time-sync.yaml /system/oem/time-sync.yaml

# Persist saved network config across upgrades (the rootfs is replaced on every
# OCI upgrade, so anything written by nmtui/nmcli would otherwise be lost).
COPY custom_bind_mounts.yaml /system/oem/custom_bind_mounts.yaml
