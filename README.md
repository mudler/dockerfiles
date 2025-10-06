# Dockerfiles

Yet another stack of Dockerfiles!

## Images


| Image | Description | Usage |
| --- | --- | --- |
| `ghcr.io/mudler/dockerfiles/nvidia-kairos` | Nvidia l4t kairos image to run dockerized workload | [Nvidia Kairos](#nvidia-kairos) |
| `ghcr.io/mudler/dockerfiles/nvidia-l4t-unsloth` | A ready to use image for fine-tuning | [Unsloth image](#unsloth-image) |
| `ghcr.io/mudler/dockerfiles/github-runner` | Self-hosted GitHub Actions runner | [GitHub Runner](#github-runner) |
| `ghcr.io/mudler/dockerfiles/kairos-wifi` | Kairos image with WiFi tools | [Kairos WiFi](#kairos-wifi) |
| `ghcr.io/mudler/dockerfiles/openstam` | OpenStaManager application | [OpenStaManager](#openstamanager) |


## Usage

### Nvidia Kairos

The image's purpose is to be used as an OS image for [Kairos](https://kairos.io). If you have for instance an Nvidia device running with Kairos (e.g. [Nvidia AGX Orin](https://kairos.io/docs/installation/nvidia_agx_orin/)), all you have to do is to upgrade the OS image:

```bash
kairos-agent upgrade --source oci:ghcr.io/mudler/dockerfiles/nvidia-kairos:master
```

the OS now will have docker installed and ready to use the GPU.

Additional tools added to the image:

- `docker`
- `jtop` (for stats monitoring)
- `tmux`
- `vim`

### Unsloth image

The image is a ready to use image for fine-tuning models which works with Nvidia L4T devices (tested with Nvidia AGX Orin). It contains the following tools:

- `unsloth` (current)
- `torch` (2.5)
- `torchvision` (2.5)
- `torchaudio` (0.20) 
- `xformers` (current)
- `jupyterlab`

The image is ready to use with the following command to run a console:

```bash
docker run -ti --runtime nvidia --entrypoint /bin/bash --gpus all --rm -v $PWD/huggingface_cache:/root/.cache/huggingface/hub ghcr.io/mudler/dockerfiles/nvidia-l4t-unsloth:latest
```

You can find training examples in `/work/examples`.

To start it with jupyter lab:

```bash
docker run -ti --runtime nvidia -p 9090:9090 --gpus all --rm -v $PWD/huggingface_cache:/root/.cache/huggingface/hub ghcr.io/mudler/dockerfiles/nvidia-l4t-unsloth:latest
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

A Kairos-based image with WiFi management tools. Based on openSUSE Leap with Kairos, it includes:

- `iw` (wireless device configuration)
- `wpa_supplicant` (WiFi authentication)

Use this image when you need WiFi capabilities in your Kairos deployment.

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
