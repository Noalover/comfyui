#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# LOGGING
# ============================================================

mkdir -p /workspace
exec > >(tee -a /workspace/provision_debug.log) 2>&1

log(){ echo "[provision] $*"; }

env_len() {
  local var_name="$1"
  local value="${!var_name:-}"
  echo "${#value}"
}

log "SCRIPT STARTED at $(date)"
log "whoami=$(whoami)"
log "pwd=$(pwd)"
log "WORKSPACE=${WORKSPACE:-unset}"
log "CIVITAI_TOKEN length=$(env_len CIVITAI_TOKEN)"
log "HF_TOKEN length=$(env_len HF_TOKEN)"
log "HUGGINGFACE_HUB_TOKEN length=$(env_len HUGGINGFACE_HUB_TOKEN)"

# ============================================================
# USER CONFIG
# ============================================================

APT_PACKAGES=(
  "aria2"
  "curl"
  "wget"
  "git"
)

PIP_PACKAGES=(
  "gdown"
)

NODES=(
  "https://github.com/ltdrdata/ComfyUI-Manager"
  "https://github.com/cubiq/ComfyUI_essentials"
  "https://github.com/AlekPet/ComfyUI_Custom_Nodes_AlekPet"
  "https://github.com/kijai/ComfyUI-KJNodes"
  "https://github.com/rgthree/rgthree-comfy"
  "https://github.com/NyaamZ/efficiency-nodes-ED"
  "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
  "https://github.com/willmiao/ComfyUI-Lora-Manager"
  "https://github.com/ssitu/ComfyUI_UltimateSDUpscale"
  "https://github.com/jags111/efficiency-nodes-comfyui"
  "https://github.com/kohya-ss/ComfyUI-Anima-LLLite"
  "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
  "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
)

CHECKPOINT_MODELS=(
  #"https://civitai.com/api/download/models/1555027?type=Model&format=SafeTensor"
  "https://civitai.com/api/download/models/2167369?type=Model&format=SafeTensor&size=pruned&fp=fp16"
)

CLIP_VISION_MODELS=(
)

UNET_MODELS=(
  #"https://civitai.com/api/download/models/2513182?type=Model&format=SafeTensor&size=pruned&fp=fp8"
)

LORA_MODELS=(
  #"https://civitai.com/api/download/models/2553688?type=Model&format=SafeTensor"
)

VAE_MODELS=(
  "https://civitai.com/api/download/models/155933?type=Model&format=SafeTensor"
  "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors?download=true"
  "https://huggingface.co/Tongyi-MAI/Z-Image-Turbo/resolve/main/vae/diffusion_pytorch_model.safetensors"
)

UPSCALE_MODELS=(
  "https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/main/2x-AnimeSharpV4_RCAN.safetensors"
  "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth"
)

CONTROLNET_MODELS=(
  "https://huggingface.co/kohya-ss/Anima-LLLite/resolve/main/anima-lllite-any-test-like-v2.safetensors"
  "https://huggingface.co/kohya-ss/Anima-LLLite/resolve/main/anima-lllite-inpainting-v2.safetensors"
)

DIFFUSION_MODELS=(
  #"https://civitai.com/api/download/models/2513182?type=Model&format=SafeTensor&size=pruned&fp=fp8"
  #"https://civitai.com/api/download/models/2957298?type=Model&format=SafeTensor&size=pruned&fp=bf16"
  "https://civitai.red/api/download/models/3145814?fileId=3026258"
  #"https://civitai.com/api/download/models/2983680?fileId=2863158"
  #"https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-base-v1.0.safetensors"
  "https://civitai.red/api/download/models/3075206?fileId=2954323"
)

TEXT_ENCODER_MODELS=(
  "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors?download=true"
  "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q6_K.gguf"
  "https://huggingface.co/Comfy-Org/Krea-2/blob/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"
)

# ============================================================
# INTERNAL CONFIG
# ============================================================

WORKSPACE="${WORKSPACE:-/workspace}"
COMFY_WORKSPACE="/workspace/ComfyUI"
INTERNAL_COMFY="/opt/workspace-internal/ComfyUI"

PYTHON_BIN="${PYTHON_BIN:-/venv/main/bin/python}"
PIP_BIN="${PIP_BIN:-/venv/main/bin/pip}"

APT_INSTALL="${APT_INSTALL:-apt-get install -y --no-install-recommends}"

NODE_REQ_FAILS=()
MODEL_DL_FAILS=()

FAIL_ON_MODEL_DL="${FAIL_ON_MODEL_DL:-0}"

# Network / install robustness. Vast hosts sometimes reset GitHub connections.
GIT_TIMEOUT="${GIT_TIMEOUT:-180}"
GIT_RETRIES="${GIT_RETRIES:-3}"
PIP_REQ_TIMEOUT="${PIP_REQ_TIMEOUT:-900}"

# ============================================================
# PATH / TOKEN HELPERS
# ============================================================

get_hf_token() {
  if [[ -n "${HF_TOKEN:-}" ]]; then
    echo "$HF_TOKEN"
    return 0
  fi

  if [[ -n "${HUGGINGFACE_HUB_TOKEN:-}" ]]; then
    echo "$HUGGINGFACE_HUB_TOKEN"
    return 0
  fi

  echo ""
}

normalize_comfy_paths() {
  if [[ -d "$INTERNAL_COMFY" && -f "$INTERNAL_COMFY/main.py" ]]; then
    if [[ ! -e "$COMFY_WORKSPACE" ]]; then
      ln -sfn "$INTERNAL_COMFY" "$COMFY_WORKSPACE"
      log "Linked $COMFY_WORKSPACE -> $INTERNAL_COMFY"
    else
      log "$COMFY_WORKSPACE already exists"
    fi
  fi

  if [[ ! -f "$COMFY_WORKSPACE/main.py" ]]; then
    log "ERROR: ComfyUI not found at $COMFY_WORKSPACE"
    exit 1
  fi

  log "ComfyUI found at $COMFY_WORKSPACE"
}

pip_install() {
  if [[ -x "$PIP_BIN" ]]; then
    "$PIP_BIN" install --no-cache-dir "$@"
    return 0
  fi

  if [[ -x "$PYTHON_BIN" ]]; then
    "$PYTHON_BIN" -m pip install --no-cache-dir "$@"
    return 0
  fi

  pip install --no-cache-dir "$@"
}

run_with_retries() {
  local attempts="$1"
  shift
  local timeout_sec="$1"
  shift
  local desc="$1"
  shift

  local n=1
  local rc=0

  while [[ "$n" -le "$attempts" ]]; do
    log "$desc (attempt $n/$attempts, timeout=${timeout_sec}s)"

    set +e
    timeout "$timeout_sec" "$@"
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
      return 0
    fi

    log "$desc failed with rc=$rc"
    sleep $((5 * n))
    n=$((n + 1))
  done

  return "$rc"
}

pip_install_timed() {
  local timeout_sec="$1"
  shift

  if [[ -x "$PIP_BIN" ]]; then
    timeout "$timeout_sec" "$PIP_BIN" install --no-cache-dir "$@"
    return $?
  fi

  if [[ -x "$PYTHON_BIN" ]]; then
    timeout "$timeout_sec" "$PYTHON_BIN" -m pip install --no-cache-dir "$@"
    return $?
  fi

  timeout "$timeout_sec" pip install --no-cache-dir "$@"
}

patch_node_requirements() {
  local repo="$1"
  local requirements="$2"

  # Impact Pack's SAM2 dependency can spend forever building on some Vast images.
  # Keep Impact Pack itself, but disable only the SAM2 source-build dependency.
  if grep -q 'facebookresearch/sam2' "$requirements" 2>/dev/null; then
    log "Patching requirements: disabling facebookresearch/sam2 in $requirements"
    sed -i '/facebookresearch\/sam2/s/^/# /' "$requirements"
  fi

  # Avoid accidental duplicate comment prefixes after repeated provisioning attempts.
  sed -i 's/^# # /# /' "$requirements" || true
}

provisioning_tune_git() {
  log "Tuning git for unstable host networking..."
  git config --global http.version HTTP/1.1 || true
  git config --global http.lowSpeedLimit 1 || true
  git config --global http.lowSpeedTime 60 || true
  git config --global advice.detachedHead false || true
  export GIT_TERMINAL_PROMPT=0
}

# ============================================================
# INSTALL PACKAGES
# ============================================================

provisioning_get_apt_packages() {
  if [[ ${#APT_PACKAGES[@]} -gt 0 ]]; then
    log "Installing apt packages: ${APT_PACKAGES[*]}"

    if command -v sudo >/dev/null 2>&1; then
      sudo apt-get update
      sudo $APT_INSTALL "${APT_PACKAGES[@]}"
    else
      apt-get update
      $APT_INSTALL "${APT_PACKAGES[@]}"
    fi
  fi
}

provisioning_get_pip_packages() {
  if [[ ${#PIP_PACKAGES[@]} -gt 0 ]]; then
    log "Installing pip packages: ${PIP_PACKAGES[*]}"
    pip_install "${PIP_PACKAGES[@]}"
  fi
}

# ============================================================
# HF_TRANSFER SUPPORT
# ============================================================

provisioning_enable_hf_transfer() {
  log "Enabling hf_transfer best-effort..."

  set +e
  pip_install -q hf_transfer huggingface_hub
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log "hf_transfer/huggingface_hub install failed. Continuing with fallback."
  else
    export HF_HUB_ENABLE_HF_TRANSFER=1
    log "hf_transfer enabled"
  fi
}

provisioning_hf_transfer_download() {
  local dir="$1"
  local url="$2"

  if [[ ! "$url" =~ ^https://huggingface\.co/ ]]; then
    return 1
  fi

  if [[ "$url" != *"/resolve/"* ]]; then
    return 1
  fi

  local clean="${url%%\?*}"
  local rest="${clean#https://huggingface.co/}"

  local repo_id="${rest%%/resolve/*}"
  local after="${rest#${repo_id}/resolve/}"
  local rev="${after%%/*}"
  local file_path="${after#${rev}/}"

  if [[ -z "$repo_id" || -z "$rev" || -z "$file_path" || "$file_path" == "$after" ]]; then
    return 1
  fi

  mkdir -p "$dir"

  log "HF attempt: repo=$repo_id rev=$rev file=$file_path -> $dir"

  set +e
  "$PYTHON_BIN" - <<'PY' "$repo_id" "$rev" "$file_path" "$dir"
import os
import sys
import shutil

repo_id, rev, file_path, out_dir = sys.argv[1:5]
token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_HUB_TOKEN") or None

try:
    from huggingface_hub import hf_hub_download
except Exception as e:
    print("[provision] huggingface_hub not available:", repr(e))
    sys.exit(2)

try:
    local_path = hf_hub_download(
        repo_id=repo_id,
        filename=file_path,
        revision=rev,
        token=token,
        cache_dir="/workspace/.hf_cache",
    )

    os.makedirs(out_dir, exist_ok=True)
    dst = os.path.join(out_dir, os.path.basename(file_path))
    shutil.copy2(local_path, dst)

    print(f"[provision] HF downloaded OK -> {dst}")
    sys.exit(0)

except Exception as e:
    print("[provision] HF failed:", repr(e))
    sys.exit(1)
PY
  local rc=$?
  set -e

  if [[ $rc -eq 0 ]]; then
    return 0
  fi

  return 1
}

# ============================================================
# FILE VALIDATION
# ============================================================

validate_downloaded_file_in_dir() {
  local dir="$1"
  local before_list="$2"

  local after_list
  after_list="$(mktemp)"

  find "$dir" -maxdepth 1 -type f -printf '%p\n' | sort > "$after_list"

  local new_files
  new_files="$(comm -13 "$before_list" "$after_list" || true)"

  rm -f "$after_list"

  if [[ -z "$new_files" ]]; then
    log "WARNING: No new file detected in $dir. Maybe already existed, or download failed."
    return 0
  fi

  local ok=0

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    local size
    size="$(stat -c%s "$file" 2>/dev/null || echo 0)"

    log "Downloaded file: $file"
    log "Size: $size bytes"
    file "$file" || true

    if [[ "$size" -lt 1048576 ]]; then
      log "ERROR: Downloaded file is too small: $file"
      ok=1
      continue
    fi

    case "$file" in
      *.safetensors|*.ckpt|*.pt|*.pth|*.bin)
        ;;
      *)
        log "WARNING: Unknown model extension: $file"
        ;;
    esac
  done <<< "$new_files"

  return "$ok"
}

# ============================================================
# DOWNLOADER
# ============================================================

provisioning_download_to_dir() {
  local dir="$1"
  local url="$2"

  mkdir -p "$dir"

  local final_url="$url"
  local auth_header=""

  local hf_token
  hf_token="$(get_hf_token)"

  if [[ -n "$hf_token" && "$url" =~ huggingface\.co ]]; then
    auth_header="Authorization: Bearer ${hf_token}"
  fi

  if [[ "$url" =~ civitai\.com ]]; then
    if [[ "$url" == *"token="* ]]; then
      log "Civitai URL already contains token parameter"
    elif [[ -z "${CIVITAI_TOKEN:-}" ]]; then
      log "WARNING: Civitai URL detected but CIVITAI_TOKEN is empty"
    else
      if [[ "$url" == *"?"* ]]; then
        final_url="${url}&token=${CIVITAI_TOKEN}"
      else
        final_url="${url}?token=${CIVITAI_TOKEN}"
      fi
    fi
  fi

  log "Downloading into $dir"

  if [[ "$url" =~ civitai\.com ]]; then
    log "Source: Civitai URL with token length=$(env_len CIVITAI_TOKEN)"
  else
    log "Source: $url"
  fi

  local before_list
  before_list="$(mktemp)"
  find "$dir" -maxdepth 1 -type f -printf '%p\n' | sort > "$before_list"

  # ------------------------------
  # Hugging Face
  # ------------------------------
  if [[ "$url" =~ huggingface\.co ]]; then
    if provisioning_hf_transfer_download "$dir" "$final_url"; then
      validate_downloaded_file_in_dir "$dir" "$before_list" || true
      rm -f "$before_list"
      return 0
    else
      log "HF python downloader failed. Falling back to aria2/wget/curl."
    fi
  fi

  # ------------------------------
  # Civitai
  # ------------------------------
  # Civitai는 aria2보다 curl이 안정적인 경우가 많아서 curl 우선.
  if [[ "$url" =~ civitai\.com ]]; then
    set +e

    (
      cd "$dir" && \
      curl -fL \
        --retry 5 \
        --retry-delay 5 \
        --retry-all-errors \
        -H "User-Agent: Mozilla/5.0" \
        -OJ \
        "$final_url"
    )

    local rc=$?
    set -e

    if [[ $rc -ne 0 ]]; then
      log "Civitai curl failed with rc=$rc"
      rm -f "$before_list"
      return "$rc"
    fi

    if ! validate_downloaded_file_in_dir "$dir" "$before_list"; then
      rm -f "$before_list"
      return 1
    fi

    rm -f "$before_list"
    return 0
  fi

  # ------------------------------
  # General fallback
  # ------------------------------
  local name="${url%%\?*}"
  name="${name##*/}"

  set +e

  if command -v aria2c >/dev/null 2>&1; then
    if [[ -n "$auth_header" ]]; then
      aria2c -x 16 -s 16 -k 1M --header="$auth_header" -o "$name" -d "$dir" "$final_url"
    else
      aria2c -x 16 -s 16 -k 1M -o "$name" -d "$dir" "$final_url"
    fi
    local rc=$?

  elif command -v wget >/dev/null 2>&1; then
    if [[ -n "$auth_header" ]]; then
      wget --header="$auth_header" --content-disposition --show-progress -qnc -P "$dir" "$final_url"
    else
      wget --content-disposition --show-progress -qnc -P "$dir" "$final_url"
    fi
    local rc=$?

  else
    if [[ -n "$auth_header" ]]; then
      curl -fL -H "$auth_header" -o "$dir/$name" "$final_url"
    else
      curl -fL -o "$dir/$name" "$final_url"
    fi
    local rc=$?
  fi

  set -e

  if [[ $rc -ne 0 ]]; then
    rm -f "$before_list"
    return "$rc"
  fi

  validate_downloaded_file_in_dir "$dir" "$before_list" || true
  rm -f "$before_list"
  return 0
}

provisioning_get_models_dir_urlonly() {
  local dir="$1"
  shift || true

  local arr=("$@")

  if [[ ${#arr[@]} -eq 0 ]]; then
    return 0
  fi

  for url in "${arr[@]}"; do
    if ! provisioning_download_to_dir "$dir" "$url"; then
      log "MODEL DOWNLOAD FAILED: $url"
      MODEL_DL_FAILS+=("$url")

      if [[ "$FAIL_ON_MODEL_DL" == "1" ]]; then
        log "FAIL_ON_MODEL_DL=1 -> exiting due to model download failure."
        exit 1
      fi
    fi
  done
}


# ============================================================
# IMPACT PACK / SUBPACK DETECTOR MODEL RESTORE
# ============================================================

provisioning_download_exact_file() {
  local url="$1"
  local dest="$2"

  mkdir -p "$(dirname "$dest")"

  local size=0
  if [[ -f "$dest" ]]; then
    size="$(stat -c%s "$dest" 2>/dev/null || echo 0)"
    if [[ "$size" -ge 1048576 ]]; then
      log "Detector model already exists: $dest ($size bytes)"
      return 0
    fi

    log "Detector model exists but is too small. Re-downloading: $dest ($size bytes)"
    rm -f "$dest"
  fi

  local hf_token
  hf_token="$(get_hf_token)"

  local tmp="${dest}.part"
  rm -f "$tmp"

  log "Downloading detector model -> $dest"
  log "Source: $url"

  set +e

  if [[ -n "$hf_token" && "$url" =~ huggingface\.co ]]; then
    curl -fL \
      --retry 5 \
      --retry-delay 5 \
      --retry-all-errors \
      -H "Authorization: Bearer ${hf_token}" \
      -o "$tmp" \
      "$url"
  else
    curl -fL \
      --retry 5 \
      --retry-delay 5 \
      --retry-all-errors \
      -o "$tmp" \
      "$url"
  fi

  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log "DETECTOR MODEL DOWNLOAD FAILED: $url"
    rm -f "$tmp"
    MODEL_DL_FAILS+=("$url")

    if [[ "$FAIL_ON_MODEL_DL" == "1" ]]; then
      log "FAIL_ON_MODEL_DL=1 -> exiting due to detector model download failure."
      exit 1
    fi

    return 0
  fi

  size="$(stat -c%s "$tmp" 2>/dev/null || echo 0)"
  if [[ "$size" -lt 1048576 ]]; then
    log "DETECTOR MODEL DOWNLOAD FAILED: file is too small: $tmp ($size bytes)"
    rm -f "$tmp"
    MODEL_DL_FAILS+=("$url")

    if [[ "$FAIL_ON_MODEL_DL" == "1" ]]; then
      log "FAIL_ON_MODEL_DL=1 -> exiting due to small detector model file."
      exit 1
    fi

    return 0
  fi

  mv -f "$tmp" "$dest"
  file "$dest" || true
  ls -lh "$dest" || true
}

provisioning_restore_impact_detector_models() {
  log "Restoring Impact Pack / Subpack detector models..."

  local bbox_dir="${COMFY_WORKSPACE}/models/ultralytics/bbox"
  local segm_dir="${COMFY_WORKSPACE}/models/ultralytics/segm"
  local whitelist_dir="${COMFY_WORKSPACE}/user/default/ComfyUI-Impact-Subpack"

  mkdir -p "$bbox_dir" "$segm_dir" "$whitelist_dir"

  # BBOX detector models
  provisioning_download_exact_file \
    "https://huggingface.co/licyk/comfyui-extension-models/resolve/main/ComfyUI-Impact-Pack/face_yolov8m.pt" \
    "$bbox_dir/face_yolov8m.pt"

  provisioning_download_exact_file \
    "https://huggingface.co/Tenofas/ComfyUI/resolve/d79945fb5c16e8aef8a1eb3ba1788d72152c6d96/ultralytics/bbox/Eyes.pt" \
    "$bbox_dir/Eyes.pt"

  # Some workflows expect this model in bbox even though it is a segm model.
  provisioning_download_exact_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt" \
    "$bbox_dir/person_yolov8m-seg.pt"

  # SEGM detector models
  provisioning_download_exact_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8m-seg.pt" \
    "$segm_dir/person_yolov8m-seg.pt"

  provisioning_download_exact_file \
    "https://huggingface.co/Bingsu/adetailer/resolve/main/person_yolov8s-seg.pt" \
    "$segm_dir/person_yolov8s-seg.pt"

  # Impact Subpack model whitelist. Overwrite deliberately so stale/broken entries do not survive.
  cat > "$whitelist_dir/model-whitelist.txt" <<'EOF'
bbox/face_yolov8m.pt
bbox/Eyes.pt
bbox/person_yolov8m-seg.pt
segm/person_yolov8m-seg.pt
segm/person_yolov8s-seg.pt
EOF

  log "Impact detector whitelist written: $whitelist_dir/model-whitelist.txt"

  print_dir_summary "ultralytics bbox" "$bbox_dir"
  print_dir_summary "ultralytics segm" "$segm_dir"
}

# ============================================================
# CUSTOM NODES
# ============================================================

provisioning_get_nodes() {
  local nodes_dir="${COMFY_WORKSPACE}/custom_nodes"
  mkdir -p "$nodes_dir"

  provisioning_tune_git

  for repo in "${NODES[@]}"; do
    local dir="${repo##*/}"
    local path="${nodes_dir}/${dir}"
    local requirements="${path}/requirements.txt"

    if [[ -d "$path/.git" ]]; then
      if ! run_with_retries "$GIT_RETRIES" "$GIT_TIMEOUT" "Updating node: $repo" git -C "$path" pull --ff-only; then
        log "Git pull failed or timed out. Keeping existing copy and continuing: $repo"
        NODE_REQ_FAILS+=("$repo (git pull failed)")
      fi
    else
      log "Node not present, cloning: $repo"
      rm -rf "$path"

      if ! run_with_retries "$GIT_RETRIES" "$GIT_TIMEOUT" "Cloning node: $repo" git clone --depth=1 --recursive "$repo" "$path"; then
        log "Git clone failed or timed out. Skipping this node and continuing: $repo"
        rm -rf "$path"
        NODE_REQ_FAILS+=("$repo (git clone failed)")
        continue
      fi
    fi

    requirements="${path}/requirements.txt"

    if [[ -f "$requirements" ]]; then
      log "Installing requirements: $requirements"
      patch_node_requirements "$repo" "$requirements"

      set +e
      pip_install_timed "$PIP_REQ_TIMEOUT" -r "$requirements"
      local rc=$?
      set -e

      if [[ $rc -ne 0 ]]; then
        log "Node requirements FAILED or timed out with rc=$rc: $repo"
        NODE_REQ_FAILS+=("$repo (requirements failed rc=$rc)")
      fi
    else
      log "No requirements.txt for node: $repo"
    fi
  done
}

# ============================================================
# SUMMARY / VERIFY
# ============================================================

print_dir_summary() {
  local label="$1"
  local dir="$2"

  log "---- $label: $dir ----"

  if [[ -d "$dir" ]]; then
    find "$dir" -maxdepth 1 \( -type f -o -type l \) | while read -r f; do
      ls -lh "$f" || true
    done
  else
    log "Directory missing: $dir"
  fi
}

verify_critical_models() {
  log "Verifying critical model directories..."

  print_dir_summary "checkpoints" "${COMFY_WORKSPACE}/models/checkpoints"
  print_dir_summary "vae" "${COMFY_WORKSPACE}/models/vae"
  print_dir_summary "upscale_models" "${COMFY_WORKSPACE}/models/upscale_models"
  print_dir_summary "diffusion_models" "${COMFY_WORKSPACE}/models/diffusion_models"
  print_dir_summary "text_encoders" "${COMFY_WORKSPACE}/models/text_encoders"

  local checkpoint_count
  checkpoint_count="$(find "${COMFY_WORKSPACE}/models/checkpoints" -maxdepth 1 -type f \( -name "*.safetensors" -o -name "*.ckpt" \) | wc -l || true)"

  log "Real checkpoint file count=$checkpoint_count"

  if [[ "$checkpoint_count" -eq 0 ]]; then
    log "WARNING: No real checkpoint file found in ${COMFY_WORKSPACE}/models/checkpoints"
    log "Existing default model may only be symlinked from /opt/model_store."
  fi
}

print_summary() {
  if [[ ${#NODE_REQ_FAILS[@]} -gt 0 ]]; then
    log "---- Node requirements failures ----"
    for x in "${NODE_REQ_FAILS[@]}"; do
      log "  - $x"
    done
  fi

  if [[ ${#MODEL_DL_FAILS[@]} -gt 0 ]]; then
    log "---- Model download failures ----"
    for x in "${MODEL_DL_FAILS[@]}"; do
      log "  - $x"
    done
  fi

  if [[ ${#NODE_REQ_FAILS[@]} -eq 0 && ${#MODEL_DL_FAILS[@]} -eq 0 ]]; then
    log "No recorded node/model failures."
  fi
}

# ============================================================
# START
# ============================================================

provisioning_start() {
  normalize_comfy_paths

  provisioning_get_apt_packages
  provisioning_get_nodes
  provisioning_get_pip_packages

  provisioning_enable_hf_transfer

  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/checkpoints"      "${CHECKPOINT_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/unet"             "${UNET_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/loras"            "${LORA_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/controlnet"       "${CONTROLNET_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/vae"              "${VAE_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/upscale_models"   "${UPSCALE_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/diffusion_models" "${DIFFUSION_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/text_encoders"    "${TEXT_ENCODER_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/clip_vision"      "${CLIP_VISION_MODELS[@]}"

  # Run this after all custom nodes and model downloads, because node provisioning can wipe/replace detector model folders.
  provisioning_restore_impact_detector_models

  verify_critical_models
  print_summary

  log "Provisioning complete."
}

provisioning_start
