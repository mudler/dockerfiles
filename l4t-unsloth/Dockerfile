
# docker run -ti --rm --runtime nvidia --gpus all nvcr.io/nvidia/l4t-jetpack:r36.4.0
# nvcr.io/nvidia/l4t-cuda:12.6.11-runtime
# https://forums.developer.nvidia.com/t/help-with-pytorch-torchvision-on-jetpack-6/284871/2
# https://github.com/dusty-nv/jetson-containers
FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

RUN apt-get update && apt-get install -y git python3-pip libopenblas-dev libopenblas-base libopenmpi-dev libomp-dev libcudnn9-cuda-12

# https://forums.developer.nvidia.com/t/pytorch-for-jetson/72048
RUN wget https://nvidia.box.com/shared/static/zvultzsmd4iuheykxy17s4l2n91ylpl8.whl -O torch-2.3.0-cp310-cp310-linux_aarch64.whl && \
 wget https://nvidia.box.com/shared/static/9si945yrzesspmg9up4ys380lqxjylc3.whl -O torchaudio-2.3.0+952ea74-cp310-cp310-linux_aarch64.whl && \
 wget https://nvidia.box.com/shared/static/u0ziu01c0kyji4zz3gxam79181nebylf.whl -O torchvision-0.18.0a0+6043bc2-cp310-cp310-linux_aarch64.whl

RUN python3 -m pip install --upgrade pip && python3 -m pip install numpy 'Cython<3' && python3 -m pip install --no-cache torch-2.3.0-cp310-cp310-linux_aarch64.whl torchaudio-2.3.0+952ea74-cp310-cp310-linux_aarch64.whl torchvision-0.18.0a0+6043bc2-cp310-cp310-linux_aarch64.whl

RUN pip install triton
RUN pip install packaging xformers==0.0.27

## Install unsloth
RUN pip install "bitsandbytes @ git+https://github.com/bitsandbytes-foundation/bitsandbytes.git"

RUN pip install "unsloth[cu123-torch230] @ git+https://github.com/unslothai/unsloth.git"
RUN pip install --no-deps trl peft accelerate
