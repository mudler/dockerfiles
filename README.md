# Dockerfiles

Yet another stack of Dockerfiles!

## Images


| Image | Description | Usage |
| --- | --- | --- |
| [quay.io/mudler/nvidia-kairos](https://quay.io/repository/mudler/nvidia-kairos) | Nvidia l4t kairos image to run dockerized workload | [Nvidia Kairos](#nvidia-kairos) |
| [quay.io/mudler/nvidia-l4t-unsloth](https://quay.io/repository/mudler/nvidia-l4t-unsloth) | A ready to use image for fine-tuning | [Unsloth image](#unsloth-image) |


## Usage

### Nvidia Kairos

The image's purpose is to be used as an OS image for [Kairos](https://kairos.io). If you have for instance an Nvidia device running with Kairos (e.g. [Nvidia AGX Orin](https://kairos.io/docs/installation/nvidia_agx_orin/)), all you have to do is to upgrade the OS image:

```bash
kairos-agent upgrade --source oci:quay.io/mudler/nvidia-kairos:master
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
docker run -ti --runtime nvidia --entrypoint /bin/bash --gpus all --rm -v $PWD/huggingface_cache:/root/.cache/huggingface/hub quay.io/mudler/nvidia-l4t-unsloth:latest
```

You can find training examples in `/work/examples`.

To start it with jupyter lab:

```bash
docker run -ti --runtime nvidia -p 9090:9090 --gpus all --rm -v $PWD/huggingface_cache:/root/.cache/huggingface/hub quay.io/mudler/nvidia-l4t-unsloth:latest
```

It automatically starts jupyter lab, you can access it by opening the browser and going to `http://localhost:9090`.