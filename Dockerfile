# Stage 1: Base
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04 as base

ARG FORGE_COMMIT=437c348926c9ee1bfe1f147529f164bb93f731a1
ARG TORCH_VERSION=2.1.2
ARG XFORMERS_VERSION=0.0.23.post1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on \
    SHELL=/bin/bash

WORKDIR /

# Install Ubuntu packages
RUN apt update && \
    apt -y upgrade && \
    apt install -y --no-install-recommends \
        software-properties-common \
        build-essential \
        python3.10-venv \
        python3-pip \
        python3-tk \
        python3-dev \
        nginx \
        bash \
        dos2unix \
        git \
        ncdu \
        net-tools \
        openssh-server \
        libglib2.0-0 \
        libsm6 \
        libgl1 \
        libxrender1 \
        libxext6 \
        ffmpeg \
        wget \
        curl \
        psmisc \
        rsync \
        vim \
        zip \
        unzip \
        htop \
        screen \
        tmux \
        bc \
        pkg-config \
        libcairo2-dev \
        libgoogle-perftools4 \
        libtcmalloc-minimal4 \
        apt-transport-https \
        ca-certificates && \
    update-ca-certificates && \
    apt clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen

# Set Python
RUN ln -s /usr/bin/python3.10 /usr/bin/python

# Stage 2: Install Stable Diffusion WebUI Forge and python modules
FROM base as setup

RUN mkdir -p /sd-models

# Add SDXL models and VAE
# These need to already have been downloaded:
#   wget https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/realisticVisionV51_v51VAE.safetensors
COPY realisticVisionV51_v51VAE.safetensors /sd-models/realisticVisionV51_v51VAE.safetensors

# Create and use the Python venv
RUN python3 -m venv /venv

# Clone the git repo of Stable Diffusion WebUI Forge and set version
WORKDIR /
RUN git clone https://github.com/lllyasviel/stable-diffusion-webui-forge.git && \
    cd /stable-diffusion-webui-forge && \
    git checkout ${FORGE_COMMIT}

# Install the dependencies for Stable Diffusion WebUI Forge
WORKDIR /stable-diffusion-webui-forge
ENV TORCH_INDEX_URL="https://download.pytorch.org/whl/cu121"
ENV TORCH_COMMAND="pip install torch==${TORCH_VERSION} torchvision --index-url ${TORCH_INDEX_URL}"
ENV XFORMERS_PACKAGE="xformers==${XFORMERS_VERSION}"
RUN source /venv/bin/activate && \
    ${TORCH_COMMAND} && \
    pip3 install -r requirements_versions.txt --extra-index-url ${TORCH_INDEX_URL} && \
    pip3 install ${XFORMERS_PACKAGE} &&  \
    deactivate

COPY forge/cache-sd-model.py forge/install-forge.py ./
RUN source /venv/bin/activate && \
    python3 -m install-forge --skip-torch-cuda-test && \
    deactivate

# Cache the Stable Diffusion Models
# SDXL models result in OOM kills with 8GB system memory, need 30GB+ to cache these
    #RUN source /venv/bin/activate && \
    #    python3 cache-sd-model.py --no-half-vae --no-half --xformers --use-cpu=all --ckpt /sd-models/realisticVisionV51_v51VAE.safetensors && \
    #    deactivate

# Copy Stable Diffusion WebUI Forge config files
COPY forge/relauncher.py forge/webui-user.sh forge/config.json forge/ui-config.json /stable-diffusion-webui-forge/

# ADD SDXL styles.csv
ADD https://raw.githubusercontent.com/Douleb/SDXL-750-Styles-GPT4-/main/styles.csv /stable-diffusion-webui/styles.csv

# Install Jupyter, gdown and OhMyRunPod
RUN pip3 install -U --no-cache-dir jupyterlab \
        jupyterlab_widgets \
        ipykernel \
        ipywidgets \
        gdown \
        OhMyRunPod

# Install RunPod File Uploader
RUN curl -sSL https://github.com/kodxana/RunPod-FilleUploader/raw/main/scripts/installer.sh -o installer.sh && \
    chmod +x installer.sh && \
    ./installer.sh

# Install rclone
RUN curl https://rclone.org/install.sh | bash

# Install runpodctl
RUN wget https://github.com/runpod/runpodctl/releases/download/v1.13.0/runpodctl-linux-amd64 -O runpodctl && \
    chmod a+x runpodctl && \
    mv runpodctl /usr/local/bin

# Install croc
RUN curl https://getcroc.schollz.com | bash

# Install speedtest CLI
RUN curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash && \
    apt install speedtest

# Remove existing SSH host keys
RUN rm -f /etc/ssh/ssh_host_*

# NGINX Proxy
COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY nginx/502.html /usr/share/nginx/html/502.html

# Set the template version
ENV TEMPLATE_VERSION=1.0.6

# Copy the scripts
WORKDIR /
COPY --chmod=755 scripts/* ./

# Start the container
SHELL ["/bin/bash", "--login", "-c"]
CMD [ "/start.sh" ]
