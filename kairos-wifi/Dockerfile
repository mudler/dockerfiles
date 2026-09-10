FROM quay.io/kairos/kairos-init:v4.3.0 AS kairos-init

FROM opensuse/leap:15.6 AS base-kairos
ARG VERSION=v4.3.0
ARG K8S_PROVIDER=k3s
ARG K8S_VERSION=v1.34.11+k3s1
RUN --mount=type=bind,from=kairos-init,src=/kairos-init,dst=/kairos-init \
    /kairos-init -l debug -s install -p "${K8S_PROVIDER}" \
      --provider-k3s-version "${K8S_VERSION}" --version "${VERSION}" && \
    /kairos-init -l debug -s init -p "${K8S_PROVIDER}" \
      --provider-k3s-version "${K8S_VERSION}" --version "${VERSION}"

FROM base-kairos

RUN zypper install -y iw wpa_supplicant