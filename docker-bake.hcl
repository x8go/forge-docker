variable "REGISTRY" {
    default = "docker.io"
}

variable "REGISTRY_USER" {
    default = "x8go"
}

variable "APP" {
    default = "forge"
}

variable "RELEASE" {
    default = "1.0.0"
}

variable "CU_VERSION" {
    default = "121"
}

variable "BASE_IMAGE_REPOSITORY" {
    default = "ashleykza/runpod-base"
}

variable "BASE_IMAGE_VERSION" {
    default = "1.4.0"
}

variable "CUDA_VERSION" {
    default = "12.1.1"
}

variable "TORCH_VERSION" {
    default = "2.3.0"
}


target "default" {
    dockerfile = "Dockerfile"
    tags = ["${REGISTRY}/${REGISTRY_USER}/${APP}:${RELEASE}"]
    args = {
        RELEASE = "${RELEASE}"
        BASE_IMAGE = "${BASE_IMAGE_REPOSITORY}:${BASE_IMAGE_VERSION}-cuda${CUDA_VERSION}-torch${TORCH_VERSION}"
        INDEX_URL = "https://download.pytorch.org/whl/cu${CU_VERSION}"
        TORCH_VERSION = "${TORCH_VERSION}+cu${CU_VERSION}"
        XFORMERS_VERSION = "0.0.26.post1"
        FORGE_COMMIT = "29be1da7cf2b5dccfc70fbdd33eb35c56a31ffb7"
        CIVITAI_DOWNLOADER_VERSION = "2.1.0"
        VENV_PATH = "/workspace/venvs/SD"
    }
}
