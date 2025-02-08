
# docker run -ti --rm --runtime nvidia --gpus all nvcr.io/nvidia/l4t-jetpack:r36.4.0
# https://forums.developer.nvidia.com/t/help-with-pytorch-torchvision-on-jetpack-6/284871/2
## docker run -ti --runtime nvidia --gpus all --rm -v /usr/local/hf/hub:/root/.cache/huggingface/hub
FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

RUN apt-get update && apt-get install -y git python3-pip libopenblas-dev libopenblas-base libopenmpi-dev libomp-dev libcudnn9-cuda-12

RUN python3 -m pip install --upgrade pip && python3 -m pip install packaging 'numpy<2' 'Cython<3' && python -m pip install --index-url https://pypi.jetson-ai-lab.dev/jp6/cu126/ xformers triton bitsandbytes torchaudio torchvision

# Install unsloth
RUN pip install "unsloth[cu123-torch230] @ git+https://github.com/unslothai/unsloth.git"
RUN pip install "unsloth_zoo @ git+https://github.com/unslothai/unsloth-zoo.git"

RUN pip install --no-deps trl peft accelerate "numpy<2"

## Install jupyerlab
RUN pip install jupyterlab
## Install go kernel
COPY --from=golang /usr/local/go/ /usr/local/go/
ENV PATH="/root/go/bin:/usr/local/go/bin:${PATH}"
RUN go install github.com/janpfeifer/gonb@latest && \
go install golang.org/x/tools/cmd/goimports@latest && \
go install golang.org/x/tools/gopls@latest

RUN /root/go/bin/gonb --install


RUN mkdir -p /work

COPY examples/ /work/examples

WORKDIR /work

VOLUME ["/work", "/root/.jupyter"]
# Set jupyter lab as entrypoint
EXPOSE 9090

ENV BNB_CUDA_VERSION=126
ENV JUPYTER_TOKEN="jupyter"

CMD ["sh", "-c", "exec jupyter lab --allow-root --no-browser --port 9090 --ip 0.0.0.0 --notebook-dir /work --IdentityProvider.token ${JUPYTER_TOKEN}"]
