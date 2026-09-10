# Dockerfiles

Yet another stack of Dockerfiles!

## Images


| Image | Description | Usage |
| --- | --- | --- |
| `ghcr.io/mudler/dockerfiles/kairos-orin` | Nvidia Jetson AGX Orin kairos image with docker + k3s | [Kairos Orin](#kairos-orin) |
| `ghcr.io/mudler/dockerfiles/kairos-thor` | Nvidia Jetson AGX Thor kairos image with docker | [Kairos Thor](#kairos-thor) |
| `ghcr.io/mudler/dockerfiles/kairos-dgx-spark` | Nvidia DGX Spark (GB10) kairos image, full stack | [Kairos DGX Spark](#kairos-dgx-spark) |
| `ghcr.io/mudler/dockerfiles/l4t-unsloth` | A ready to use image for fine-tuning | [Unsloth image](#unsloth-image) |
| `ghcr.io/mudler/dockerfiles/github-runner` | Self-hosted GitHub Actions runner | [GitHub Runner](#github-runner) |
| `ghcr.io/mudler/dockerfiles/kairos-wifi` | Kairos image with WiFi tools | [Kairos WiFi](#kairos-wifi) |
| `ghcr.io/mudler/dockerfiles/kairos-wifi-ubuntu` | Kairos Ubuntu amd64 image with WiFi | [Kairos WiFi (Ubuntu)](#kairos-wifi-ubuntu) |
| `ghcr.io/mudler/dockerfiles/openstam` | OpenStaManager application | [OpenStaManager](#openstamanager) |


## Usage

### Kairos Orin

An OS image for the [Nvidia Jetson AGX Orin](https://kairos.io/docs/installation/nvidia_agx_orin/) (JetPack 6 / L4T r36.x), built with `kairos-init` like [Kairos Thor](#kairos-thor) and [Kairos DGX Spark](#kairos-dgx-spark). Upgrade the board's OS image with:

```bash
kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-orin:master
```

On the next boot the OS has docker, the NVIDIA container runtime, and k3s. k3s
lets the board run workloads as Kubernetes Deployments rather than under docker
compose; its state (`/var/lib/rancher`, `/etc/rancher`, `/var/lib/kubelet`) is
persisted across OCI upgrades by the Kubernetes provider.

> Renamed from `nvidia-kairos` (2026-08-14) so it matches its siblings. The old
> repository keeps its existing tags but receives no new builds — upgrade from
> `kairos-orin` instead.

Additional tools added to the image:

- `docker` (+ NVIDIA container runtime)
- `k3s`
- `jtop` (for stats monitoring)
- `tmux`
- `vim`

### Kairos Thor

An OS image for the [Nvidia Jetson AGX Thor](https://kairos.io) (T264, JetPack 7 / L4T r39.2), same idea as [Kairos Orin](#kairos-orin) but for Thor. Upgrade the board's OS image with:

```bash
kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-thor:master
```

On the next boot the OS has docker and the NVIDIA container runtime ready. The image also carries the QSPI firmware check, which re-runs on upgrade: if the board's firmware is older than the image, it stages a UEFI capsule and flashes it on reboot.

Additional tools added to the image:

- `docker` (+ NVIDIA container runtime)
- `jtop` (for stats monitoring)
- `tmux`
- `vim`

> Note: Kairos 4.3.0 includes Thor support in `kairos-init`. Kairos v4 publishes Hadron OS artifacts only, so this image uses the supported BYOI path to assemble the rootfs on `ubuntu:24.04`.

### Kairos DGX Spark

A full-stack OS image for the [NVIDIA DGX Spark](https://www.nvidia.com/en-us/products/workstations/dgx-spark/) (GB10 Grace-Blackwell). Unlike the Jetson images, DGX Spark is a standard arm64 UEFI/SBSA machine, so it boots like any GRUB/UEFI system and uses `fwupd` for firmware. Upgrade the board's OS image with:

```bash
kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-dgx-spark:master
```

On the next boot the OS has the GPU driver, docker + the NVIDIA container runtime (run CUDA workloads in containers), and Mellanox/ConnectX networking.

Included:

- kernel + `nvidia-headless-580-open` (open GPU driver) + `nvidia-utils` (`nvidia-smi`)
- `docker` (+ NVIDIA container runtime)
- Mellanox/ConnectX networking (`rdma-core`, `nvidia-mlnx-tools`) + WiFi
- `fwupd` for firmware updates

> Note: Kairos 4.3.0 includes DGX Spark support in `kairos-init`. Kairos v4 publishes Hadron OS artifacts only, so this image uses the supported BYOI path to assemble the rootfs on `ubuntu:24.04`. The Docker and NVIDIA container stack are layered here.

### Unsloth image

> Renamed from `nvidia-l4t-unsloth` (2026-08-14) so the published name matches
> its directory and build entry, as with every other image here. The old
> repository keeps its existing tags but receives no new builds.

The image is a ready to use image for fine-tuning models which works with Nvidia L4T devices (tested with Nvidia AGX Orin). It contains the following tools:

- `unsloth` (current)
- `torch` (2.5)
- `torchvision` (2.5)
- `torchaudio` (0.20) 
- `xformers` (current)
- `jupyterlab`

The image is ready to use with the following command to run a console:

```bash
docker run -ti --runtime nvidia --entrypoint /bin/bash --gpus all --rm -v $PWD/huggingface_cache:/root/.cache/huggingface/hub ghcr.io/mudler/dockerfiles/l4t-unsloth:latest
```

You can find training examples in `/work/examples`.

To start it with jupyter lab:

```bash
docker run -ti --runtime nvidia -p 9090:9090 --gpus all --rm -v $PWD/huggingface_cache:/root/.cache/huggingface/hub ghcr.io/mudler/dockerfiles/l4t-unsloth:latest
```

It automatically starts jupyter lab, you can access it by opening the browser and going to `http://localhost:9090`.

### GitHub Runner

A self-hosted GitHub Actions runner image based on Ubuntu with Docker support. This image includes:

- Docker CE
- Git
- Python 2/3
- Common build tools (make, curl, jq)
- Network utilities (ping, etc.)

To use as a self-hosted runner, configure it with your GitHub repository's runner token.

### Kairos WiFi

A Kairos 4.3.0 BYOI image based on openSUSE Leap 15.6. It includes:

- `iw` (wireless device configuration)
- `wpa_supplicant` (WiFi authentication)

Use this image when you need WiFi capabilities in your Kairos deployment.

### Kairos WiFi (Ubuntu)

A Kairos image for a standard amd64 machine (laptop, NUC, mini-PC) that needs to
join a wireless network. Built through the Kairos 4.3.0 BYOI path on Ubuntu
24.04 with k3s, so it installs and upgrades like any other Kairos node:

```bash
kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/kairos-wifi-ubuntu:master
```

Where [Kairos WiFi](#kairos-wifi) is openSUSE with `iw` and `wpa_supplicant`
only, this one adds a NetworkManager-driven stack:

- `network-manager` (`nmtui` / `nmcli`), installed without recommends
- `wpasupplicant` and `iw`

WiFi firmware is not added: the Kairos Ubuntu base already carries
`linux-firmware`, so the image grows by only the WiFi userspace.

Join a network on the box with `nmtui`. The connection is saved under
`/etc/netplan` (Ubuntu's NetworkManager writes connections as netplan yaml) and
`/etc/NetworkManager/system-connections`, both bind-mounted onto the persistent
partition, so it survives OCI upgrades that replace the rootfs.

The image also carries a one-shot NTP clock step (`/system/oem/time-sync.yaml`),
and it is not optional on a WiFi box. NetworkManager owns the wireless device,
so systemd-networkd treats it as unmanaged, `systemd-timesyncd` never sees the
network come online and sends **zero** NTP packets. The clock keeps whatever the
RTC held, every TLS handshake fails with "certificate has expired or is not yet
valid", and the box cannot pull a single container image — k3s could not even
pull its own pause image. The one-shot steps the clock over raw SNTP once the
network is up, retrying and time-bounded so it can never hang the boot.

Wired networking is untouched. Kairos configures ethernet through
systemd-networkd and rewrites its DHCP files on every boot; Ubuntu's
NetworkManager ships `unmanaged-devices=*,except:type:wifi,...`, so it only ever
claims the wireless device and the two never contend. That default is also what
keeps NetworkManager away from the interfaces k3s creates (`cni0`, `flannel.1`,
veths) — do not override it in `/etc/NetworkManager/conf.d`.

A bootable installer ISO is built by the `build ISOs` workflow (run it manually,
or take it from a release) — useful here, since the machine may have no wired
port to install over.

### OpenStaManager

A complete OpenStaManager application image based on PHP 8.1 with Apache. This image includes:

- PHP 8.1 with Apache
- OpenStaManager v2.6.1 pre-installed
- All required PHP extensions (GD, MySQL, MongoDB, etc.)
- Composer for dependency management

To run the application:

```bash
docker run -d -p 8080:80 ghcr.io/mudler/dockerfiles/openstam:latest
```

Access the application at `http://localhost:8080`.
