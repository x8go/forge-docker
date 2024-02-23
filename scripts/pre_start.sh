#!/usr/bin/env bash

export PYTHONUNBUFFERED=1

echo "Template version: ${TEMPLATE_VERSION}"

if [[ -e "/workspace/template_version" ]]; then
    EXISTING_VERSION=$(cat /workspace/template_version)
else
    EXISTING_VERSION="0.0.0"
fi

sync_apps() {
    # Sync venv to workspace to support Network volumes
    echo "Syncing venv to workspace, please wait..."
    rsync -rlptDu /venv/ /workspace/venv/

    # Sync Stable Diffusion WebUI Forge to workspace to support Network volumes
    echo "Syncing Stable Diffusion WebUI Forge to workspace, please wait..."
    rsync -rlptDu /stable-diffusion-webui-forge/ /workspace/stable-diffusion-webui-forge/

    echo "${TEMPLATE_VERSION}" > /workspace/template_version
}

fix_venvs() {
    # Fix the venv to make it work from /workspace
    echo "Fixing venv..."
    /fix_venv.sh /venv /workspace/venv
}

link_models() {
   if [[ ! -L /workspace/stable-diffusion-webui-forge/models/Stable-diffusion/realisticVisionV51_v51VAE.safetensors ]]; then
       ln -s /sd-models/realisticVisionV51_v51VAE.safetensors /workspace/stable-diffusion-webui-forge/models/Stable-diffusion/realisticVisionV51_v51VAE.safetensors
   fi
}

if [ "$(printf '%s\n' "$EXISTING_VERSION" "$TEMPLATE_VERSION" | sort -V | head -n 1)" = "$EXISTING_VERSION" ]; then
    if [ "$EXISTING_VERSION" != "$TEMPLATE_VERSION" ]; then
        sync_apps
        fix_venvs
        link_models
    else
        echo "Existing version is the same as the template version, no syncing required."
    fi
else
    echo "Existing version is newer than the template version, not syncing!"
fi

if [[ ${DISABLE_AUTOLAUNCH} ]]
then
    echo "Auto launching is disabled so the application will not be started automatically"
    echo "You can launch it manually:"
    echo ""
    echo "   cd /workspace/stable-diffusion-webui-forge"
    echo "   deactivate && source /workspace/venv/bin/activate"
    echo "   ./webui.sh -f"
else
    echo "Starting Stable Diffusion WebUI Forge"
    export HF_HOME="/workspace"
    source /workspace/venv/bin/activate
    cd /workspace/stable-diffusion-webui-forge
    nohup ./webui.sh -f > /workspace/logs/forge.log 2>&1 &
    echo "Stable Diffusion WebUI Forge started"
    echo "Log file: /workspace/logs/forge.log"
    deactivate
fi

echo "All services have been started"
