ARG BASE_IMAGE
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on \
    SHELL=/bin/bash

RUN mkdir -p /sd-models

# Add SDXL models and VAE
# These need to already have been downloaded:
#   wget https://huggingface.co/lllyasviel/fav_models/resolve/main/fav/realisticVisionV51_v51VAE.safetensors
#COPY realisticVisionV51_v51VAE.safetensors /sd-models/realisticVisionV51_v51VAE.safetensors

# Create and use the Python venv
RUN python3 -m venv /venv

# Clone the git repo of Stable Diffusion WebUI Forge and set version
ARG FORGE_COMMIT
RUN git clone https://huggingface.co/zuv0/SDXLF17 SD && \
    \mv -f /SD/repositories/BLIP/_git /SD/repositories/BLIP/.git && \
    \mv -f /SD/repositories/generative-models/_git /SD/repositories/generative-models/.git && \
    \mv -f /SD/repositories/k-diffusion/_git /SD/repositories/k-diffusion/.git && \
    \mv -f /SD/repositories/stable-diffusion-stability-ai/_git /SD/repositories/stable-diffusion-stability-ai/.git && \
    \mv -f /SD/repositories/stable-diffusion-webui-assets/_git /SD/repositories/stable-diffusion-webui-assets/.git && \
    cd /SD/extensions-builtin/forge_legacy_preprocessors/annotator/oneformer/oneformer/data && \
    curl -L -O https://github.com/Mikubill/sd-webui-controlnet/blob/main/annotator/oneformer/oneformer/data/bpe_simple_vocab_16e6.txt.gz && \
    cd /SD

# Install the dependencies for Stable Diffusion WebUI Forge
ARG INDEX_URL
ARG TORCH_VERSION
ARG XFORMERS_VERSION
WORKDIR /SD

# models install
RUN git clone https://huggingface.co/zuv0/modelsXL models

ENV TORCH_INDEX_URL=${INDEX_URL}
ENV TORCH_COMMAND="pip install torch==${TORCH_VERSION} torchvision --index-url ${TORCH_INDEX_URL}"
ENV XFORMERS_PACKAGE="xformers==${XFORMERS_VERSION} --index-url ${TORCH_INDEX_URL}"
RUN source /venv/bin/activate && \
    ${TORCH_COMMAND} && \
    pip3 install -r requirements_versions.txt --extra-index-url ${TORCH_INDEX_URL} && \
    pip3 install ${XFORMERS_PACKAGE} &&  \
    deactivate

# Install the dependencies for the built-in extensions
RUN source /venv/bin/activate && \
    pip3 install -r extensions-builtin/sd_forge_controlnet/requirements.txt && \
    pip3 install -r extensions-builtin/forge_legacy_preprocessors/requirements.txt && \
    pip3 install insightface && \
    pip3 uninstall -y onnxruntime && \
    pip3 install onnxruntime-gpu && \
    pip install pydantic==1.10.11 && \
    deactivate

COPY forge/cache-sd-model.py ./
RUN source /venv/bin/activate && \
    python3 -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test && \
    deactivate

# Cache the Stable Diffusion Models
# SDXL models result in OOM kills with 8GB system memory, need 30GB+ to cache these
    #RUN source /venv/bin/activate && \
    #    python3 cache-sd-model.py --no-half-vae --no-half --xformers --use-cpu=all --ckpt /sd-models/realisticVisionV51_v51VAE.safetensors && \
    #    deactivate

# Copy Stable Diffusion WebUI Forge config files
#COPY forge/relauncher.py forge/webui-user.sh forge/config.json forge/ui-config.json /SD/
COPY forge/relauncher.py forge/webui-user.sh /SD/

# ADD SDXL styles.csv
#ADD https://raw.githubusercontent.com/Douleb/SDXL-750-Styles-GPT4-/main/styles.csv /stable-diffusion-webui/styles.csv

# Install CivitAI Model Downloader
#ARG CIVITAI_DOWNLOADER_VERSION
#RUN git clone https://github.com/ashleykleynhans/civitai-downloader.git && \
#    cd civitai-downloader && \
#    git checkout tags/${CIVITAI_DOWNLOADER_VERSION} && \
#    cp download.py /usr/local/bin/download-model && \
#    chmod +x /usr/local/bin/download-model && \
#    cd .. && \
#    rm -rf civitai-downloader

# Remove existing SSH host keys
RUN rm -f /etc/ssh/ssh_host_*

# NGINX Proxy
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Set template version
ARG RELEASE
ENV TEMPLATE_VERSION=${RELEASE}

# Set the venv path
ARG VENV_PATH
ENV VENV_PATH=${VENV_PATH}

# Copy the scripts
WORKDIR /
COPY --chmod=755 scripts/* ./

# Start the container
SHELL ["/bin/bash", "--login", "-c"]
CMD [ "/start.sh" ]
