#!/bin/bash

source /venv/main/bin/activate
COMFYUI_DIR=${WORKSPACE}/ComfyUI

# Packages are installed after nodes so we can fix them...

APT_PACKAGES=(
    #"package-1"
    #"package-2"
)

PIP_PACKAGES=(
    "hf-transfer"
    "huggingface_hub"
    "gdown" # Google Drive support
)

NODES=(
    "https://github.com/ltdrdata/ComfyUI-Manager"
    "https://github.com/Lightricks/ComfyUI-LTXVideo"
    "https://github.com/kijai/ComfyUI-KJNodes"
    "https://github.com/ClownsharkBatwing/RES4LYF"
    "https://github.com/city96/ComfyUI-GGUF"
    "https://github.com/monnky/ComfyUI-Monnky-LTXV2"
    "https://github.com/crystian/ComfyUI-Crystools"
    "https://github.com/rgthree/rgthree-comfy"
    "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
    "https://github.com/yolain/ComfyUI-Easy-Use"
    "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
    "https://github.com/evanspearman/ComfyMath"
)

WORKFLOWS=(

)

CHECKPOINT_MODELS=(
    #"https://civitai.com/api/download/models/798204?type=Model&format=SafeTensor&size=full&fp=fp16"
    #"https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled.safetensors"
    #"https://huggingface.co/Lightricks/LTX-2/resolve/main/ltx-2-19b-distilled-fp8.safetensors"
)

DIFFUSION_MODELS=(
    "https://drive.google.com/file/d/1gwzUlOIdXsKjb3TotDJLl9sPq6Pz0ODt"
)

UNET_MODELS=(
)

LORA_MODELS=(
    "https://drive.google.com/file/d/1s_tEAGyFBRFryLVQez-L9gncnetIMVNa"
)

VAE_MODELS=(
    "https://drive.google.com/file/d/1iNJyFGk4JZfrFp9hLYvi_-a1Hg_ScHKH"
    "https://drive.google.com/file/d/1MZH71D6Iad4EQKXv3ii-umaePEilBmRL"
)

ESRGAN_MODELS=(
)

CONTROLNET_MODELS=(
)

# LTX-2 Specific Arrays
TEXT_ENCODERS=(
    "https://drive.google.com/file/d/1aeoilAkhhf76w9M_30cxaP1fKaIR452V"
    "https://drive.google.com/file/d/1mxfr9O3IhZFtDNotYNG-cE5rps-pGyKs"
)

LATENT_UPSCALE_MODELS=(
    "https://drive.google.com/file/d/1RGjBNTYuuNMT6FW2Hw-cRbV4kM8PPbWW"
)

#######################################################################################
function provisioning_start() {
    provisioning_print_header
    provisioning_get_apt_packages
    provisioning_get_pip_packages # Moved up to ensure gdown is ready
    provisioning_get_nodes
    
    # ... (Rest of provisioning_start)
    provisioning_get_files \
        "${COMFYUI_DIR}/models/checkpoints" \
        "${CHECKPOINT_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/diffusion_models" \
        "${DIFFUSION_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/unet" \
        "${UNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/loras" \
        "${LORA_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/controlnet" \
        "${CONTROLNET_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/vae" \
        "${VAE_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/esrgan" \
        "${ESRGAN_MODELS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/text_encoders" \
        "${TEXT_ENCODERS[@]}"
    provisioning_get_files \
        "${COMFYUI_DIR}/models/latent_upscale_models" \
        "${LATENT_UPSCALE_MODELS[@]}"
    provisioning_print_end
}

function provisioning_get_apt_packages() {
    if [[ -n $APT_PACKAGES ]]; then
            sudo $APT_INSTALL ${APT_PACKAGES[@]}
    fi
}

function provisioning_get_pip_packages() {
    if [[ -n $PIP_PACKAGES ]]; then
            pip install --no-cache-dir ${PIP_PACKAGES[@]}
    fi
}

function provisioning_get_nodes() {
    for repo in "${NODES[@]}"; do
        dir="${repo##*/}"
        path="${COMFYUI_DIR}/custom_nodes/${dir}"
        requirements="${path}/requirements.txt"
        if [[ -d $path ]]; then
            if [[ ${AUTO_UPDATE,,} != "false" ]]; then
                printf "Updating node: %s...\n" "${repo}"
                ( cd "$path" && git pull )
                if [[ -e $requirements ]]; then
                   pip install --no-cache-dir -r "$requirements"
                fi
            fi
        else
            printf "Downloading node: %s...\n" "${repo}"
            git clone "${repo}" "${path}" --recursive
            if [[ -e $requirements ]]; then
                pip install --no-cache-dir -r "${requirements}"
            fi
        fi
    done
}

function provisioning_get_files() {
    if [[ -z $2 ]]; then return 1; fi
    
    dir="$1"
    mkdir -p "$dir"
    shift
    arr=("$@")
    printf "Downloading %s model(s) to %s...\n" "${#arr[@]}" "$dir"
    for url in "${arr[@]}"; do
        printf "Downloading: %s\n" "${url}"
        provisioning_download "${url}" "${dir}"
        printf "\n"
    done
}

function provisioning_print_header() {
    printf "\n##############################################\n#                                            #\n#          Provisioning container            #\n#                                            #\n#         This will take some time           #\n#                                            #\n# Your container will be ready on completion #\n#                                            #\n##############################################\n\n"
}

function provisioning_print_end() {
    printf "\nProvisioning complete:  Application will start now\n\n"
}

function provisioning_has_valid_hf_token() {
    [[ -n "$HF_TOKEN" ]] || return 1
    url="https://huggingface.co/api/whoami-v2"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $HF_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_has_valid_civitai_token() {
    [[ -n "$CIVITAI_TOKEN" ]] || return 1
    url="https://civitai.com/api/v1/models?hidden=1&limit=1"

    response=$(curl -o /dev/null -s -w "%{http_code}" -X GET "$url" \
        -H "Authorization: Bearer $CIVITAI_TOKEN" \
        -H "Content-Type: application/json")

    # Check if the token is valid
    if [ "$response" -eq 200 ]; then
        return 0
    else
        return 1
    fi
}

function provisioning_download() {
    # 1. Check if it's a Hugging Face URL
    if [[ $1 =~ ^https://huggingface\.co/([^/]+)/([^/]+)/resolve/([^/]+)/(.*)$ ]]; then
        repo_owner="${BASH_REMATCH[1]}"
        repo_name="${BASH_REMATCH[2]}"
        repo_id="$repo_owner/$repo_name"
        filename="${BASH_REMATCH[4]}"
        
        printf "  Detected Hugging Face URL. Using high-speed CLI...\n"
        export HF_HUB_ENABLE_HF_TRANSFER=1
        local token_auth=""
        [[ -n $HF_TOKEN ]] && token_auth="--token $HF_TOKEN"

        hf download "$repo_id" "$filename" --local-dir "$2" $token_auth

    # 2. Check if it's a Google Drive URL
    elif [[ $1 =~ drive\.google\.com ]]; then
        printf "  Detected Google Drive URL. Using gdown...\n"
        # Ensure gdown is available in path
        if command -v gdown &> /dev/null; then
            gdown --fuzzy "$1" -O "$2/" --remaining-ok
        else
            printf "  Error: gdown not found. Falling back to wget (this may fail for large files).\n"
            wget -qnc --content-disposition --show-progress -P "$2" "$1"
        fi

    # 3. Fallback for CivitAI or other URLs
    else
        local auth_token=""
        if [[ -n $CIVITAI_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?civitai\.com(/|$|\?) ]]; then
            auth_token="$CIVITAI_TOKEN"
        elif [[ -n $HF_TOKEN && $1 =~ ^https://([a-zA-Z0-9_-]+\.)?huggingface\.co(/|$|\?) ]]; then
            auth_token="$HF_TOKEN"
        fi

        if [[ -n $auth_token ]]; then
            wget --header="Authorization: Bearer $auth_token" -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
        else
            wget -qnc --content-disposition --show-progress -e dotbytes="${3:-4M}" -P "$2" "$1"
        fi
    fi
}

# Allow user to disable provisioning
if [[ ! -f /.noprovisioning ]]; then
    provisioning_start
fi