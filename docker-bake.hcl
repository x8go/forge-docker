variable "USERNAME" {
    default = "ashleykza"
}

variable "APP" {
    default = "forge"
}

variable "RELEASE" {
    default = "2.0.1"
}

variable "CU_VERSION" {
    default = "118"
}

target "default" {
    dockerfile = "Dockerfile"
    tags = ["${USERNAME}/${APP}:${RELEASE}"]
    args = {
        RELEASE = "${RELEASE}"
        INDEX_URL = "https://download.pytorch.org/whl/cu${CU_VERSION}"
        TORCH_VERSION = "2.1.2+cu${CU_VERSION}"
        XFORMERS_VERSION = "0.0.23.post1+cu${CU_VERSION}"
        FORGE_COMMIT = "29be1da7cf2b5dccfc70fbdd33eb35c56a31ffb7"
        RUNPODCTL_VERSION = "v1.14.2"
        CIVITAI_DOWNLOADER_VERSION = "2.0.1"
        VENV_PATH = "/workspace/venvs/stable-diffusion-webui-forge"
    }
}
