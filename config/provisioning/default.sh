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
  "https://github.com/yolain/ComfyUI-Easy-Sam3"
  # Fish Audio S2 Pro TTS / zero-shot voice cloning.
  # FP8 weights are pre-downloaded separately below for fresh Vast instances.
  "https://github.com/Saganaki22/ComfyUI-FishAudioS2"
)

CHECKPOINT_MODELS=(
  #"https://civitai.com/api/download/models/1555027?type=Model&format=SafeTensor"
  #"https://civitai.com/api/download/models/2167369?type=Model&format=SafeTensor&size=pruned&fp=fp16"
)

# SAM 3.1: keep one physical copy in models/checkpoints for native ComfyUI.
# Easy-SAM3 expects the model under models/sam3, so a symlink is created later.
SAM31_MODELS=(
  "https://huggingface.co/Comfy-Org/sam3.1/resolve/main/checkpoints/sam3.1_multiplex_fp16.safetensors"
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
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors"
)

UPSCALE_MODELS=(
  #"https://huggingface.co/Kim2091/2x-AnimeSharpV4/resolve/main/2x-AnimeSharpV4_RCAN.safetensors"
  #"https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x_NMKD-Siax_200k.pth"
)

CONTROLNET_MODELS=(
  "https://huggingface.co/kohya-ss/Anima-LLLite/resolve/main/anima-lllite-any-test-like-v2.safetensors"
  "https://huggingface.co/kohya-ss/Anima-LLLite/resolve/main/anima-lllite-inpainting-v2.safetensors"
)

DIFFUSION_MODELS=(
  "https://civitai.com/api/download/models/3126581?fileId=3007030"
  #"https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-base-v1.0.safetensors"
  #"https://civitai.com/api/download/models/3075206?fileId=2954323"
  #"https://civitai.com/api/download/models/3112659?fileId=2992771"
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors"
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_ref2va_pruned_int8_convrot.safetensors"
)

TEXT_ENCODER_MODELS=(
  "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors?download=true"
  #"https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q6_K.gguf"
  #"https://huggingface.co/Comfy-Org/Krea-2/resolve/main/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"
  "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_int8_convrot.safetensors"
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

# Host preflight.
# 1: run checks and abort provisioning when the host cannot reach required services.
# 0: skip the checks.
HOST_PREFLIGHT="${HOST_PREFLIGHT:-1}"
PREFLIGHT_ATTEMPTS="${PREFLIGHT_ATTEMPTS:-2}"
PREFLIGHT_CONNECT_TIMEOUT="${PREFLIGHT_CONNECT_TIMEOUT:-8}"
PREFLIGHT_TOTAL_TIMEOUT="${PREFLIGHT_TOTAL_TIMEOUT:-25}"

# Reject instances that have too little free disk before large model downloads.
# A 130 GB Vast volume usually has less than 130 GiB actually free because the image also uses space.
PREFLIGHT_MIN_FREE_GB="${PREFLIGHT_MIN_FREE_GB:-100}"

# Remove the old full-size Hugging Face cache created by earlier versions of this script.
# This cache duplicated every downloaded model. Set to 0 only if you intentionally need it.
CLEAN_LEGACY_HF_CACHE="${CLEAN_LEGACY_HF_CACHE:-1}"
LEGACY_HF_CACHE_DIR="${LEGACY_HF_CACHE_DIR:-/workspace/.hf_cache}"

# hf_hub_download(local_dir=...) uses this directory for the current file's
# resumable partial data and local metadata. It is deleted after each HF file.
HF_DOWNLOAD_TMP_DIR="${HF_DOWNLOAD_TMP_DIR:-/workspace/.hf_download_tmp}"

# Contain every Hugging Face/Xet cache created by this script in one disposable directory.
# This prevents writes to /root/.cache/huggingface.
HF_RUNTIME_CACHE_DIR="${HF_RUNTIME_CACHE_DIR:-/workspace/.hf_runtime_cache}"

# Remove a default-path Xet cache left by the previous script version.
LEGACY_DEFAULT_HF_XET_CACHE="${LEGACY_DEFAULT_HF_XET_CACHE:-${HOME:-/root}/.cache/huggingface/xet}"

# Longer timeouts are safer on inconsistent Vast hosts.
HF_ETAG_TIMEOUT="${HF_ETAG_TIMEOUT:-30}"
HF_DOWNLOAD_TIMEOUT="${HF_DOWNLOAD_TIMEOUT:-60}"

# Fish Audio S2 Pro FP8.
# drbaph/s2-pro-fp8 is already weight-quantized to FP8, so bitsandbytes is not
# required. Fresh Vast instances pre-download it during provisioning so the
# first ComfyUI generation does not need another ~8 GB model download.
FISH_S2_PRELOAD="${FISH_S2_PRELOAD:-1}"
FISH_S2_REPO="${FISH_S2_REPO:-drbaph/s2-pro-fp8}"
FISH_S2_MODEL_DIR="${FISH_S2_MODEL_DIR:-${COMFY_WORKSPACE}/models/fishaudioS2/s2-pro-fp8}"

PREFLIGHT_FAILURES=()

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
# HUGGING FACE TEMP/CACHE MANAGEMENT
# ============================================================

provisioning_cleanup_legacy_hf_cache() {
  if [[ "$CLEAN_LEGACY_HF_CACHE" != "1" ]]; then
    log "Legacy HF cache cleanup disabled (CLEAN_LEGACY_HF_CACHE=$CLEAN_LEGACY_HF_CACHE)"
    return 0
  fi

  local path
  for path in "$LEGACY_HF_CACHE_DIR" "$LEGACY_DEFAULT_HF_XET_CACHE"; do
    [[ -z "$path" ]] && continue
    [[ ! -d "$path" ]] && continue

    local cache_size
    cache_size="$(du -sh "$path" 2>/dev/null | awk '{print $1}' || true)"
    log "Removing legacy HF cache: $path (${cache_size:-unknown})"
    rm -rf -- "$path"
  done
}

provisioning_configure_hf_runtime() {
  mkdir -p "$HF_DOWNLOAD_TMP_DIR" "$HF_RUNTIME_CACHE_DIR"

  # huggingface_hub reads these variables when imported by each Python subprocess.
  export HF_HOME="$HF_RUNTIME_CACHE_DIR"
  export HF_HUB_CACHE="$HF_RUNTIME_CACHE_DIR/hub"
  export HF_XET_CACHE="$HF_RUNTIME_CACHE_DIR/xet"
  export HF_ASSETS_CACHE="$HF_RUNTIME_CACHE_DIR/assets"
  export HF_TOKEN_PATH="$HF_RUNTIME_CACHE_DIR/token"

  # The Xet chunk cache is unnecessary for one-shot Vast downloads.
  export HF_XET_CHUNK_CACHE_SIZE_BYTES=0
  export HF_XET_SHARD_CACHE_SIZE_LIMIT=0

  export HF_HUB_ETAG_TIMEOUT="$HF_ETAG_TIMEOUT"
  export HF_HUB_DOWNLOAD_TIMEOUT="$HF_DOWNLOAD_TIMEOUT"
}

provisioning_cleanup_hf_artifacts() {
  local path
  for path in "$HF_DOWNLOAD_TMP_DIR" "$HF_RUNTIME_CACHE_DIR"; do
    [[ -z "$path" ]] && continue
    [[ ! -d "$path" ]] && continue

    local size
    size="$(du -sh "$path" 2>/dev/null | awk '{print $1}' || true)"
    log "Removing disposable HF data: $path (${size:-unknown})"
    rm -rf -- "$path"
  done
}

provisioning_hf_exit_cleanup() {
  # EXIT runs after normal completion, handled failures, Ctrl+C and SIGTERM.
  # SIGKILL or an abrupt host loss cannot run shell cleanup; the next run
  # deletes these directories at startup.
  provisioning_cleanup_hf_artifacts || true
}

# ============================================================
# HOST PREFLIGHT
# ============================================================

preflight_record_failure() {
  local message="$1"
  PREFLIGHT_FAILURES+=("$message")
  log "[HOST CHECK: FAIL] $message"
}

preflight_retry_command() {
  local label="$1"
  shift

  local attempt=1
  local rc=1

  while [[ "$attempt" -le "$PREFLIGHT_ATTEMPTS" ]]; do
    log "[HOST CHECK] $label (attempt $attempt/$PREFLIGHT_ATTEMPTS)"

    set +e
    timeout "$PREFLIGHT_TOTAL_TIMEOUT" "$@"
    rc=$?
    set -e

    if [[ $rc -eq 0 ]]; then
      log "[HOST CHECK: OK] $label"
      return 0
    fi

    log "[HOST CHECK] $label failed with rc=$rc"
    sleep $((3 * attempt))
    attempt=$((attempt + 1))
  done

  preflight_record_failure "$label"
  return 1
}

preflight_https() {
  local label="$1"
  local url="$2"

  preflight_retry_command \
    "$label" \
    curl -fsSL \
      --connect-timeout "$PREFLIGHT_CONNECT_TIMEOUT" \
      --max-time "$PREFLIGHT_TOTAL_TIMEOUT" \
      --retry 0 \
      -A "Mozilla/5.0" \
      -o /dev/null \
      "$url"
}

provisioning_host_preflight() {
  if [[ "$HOST_PREFLIGHT" != "1" ]]; then
    log "Host preflight disabled (HOST_PREFLIGHT=$HOST_PREFLIGHT)"
    return 0
  fi

  log "============================================================"
  log "HOST PREFLIGHT START"
  log "This check should finish in roughly 30-90 seconds."
  log "============================================================"

  PREFLIGHT_FAILURES=()
  rm -f /workspace/HOST_PREFLIGHT_FAILED /workspace/HOST_PREFLIGHT_PASSED

  # GPU visibility
  if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi >/dev/null 2>&1; then
      log "[HOST CHECK: OK] NVIDIA GPU is visible"
      nvidia-smi \
        --query-gpu=name,uuid,memory.total,driver_version \
        --format=csv,noheader || true
    else
      preflight_record_failure "nvidia-smi exists but cannot access the GPU"
    fi
  else
    preflight_record_failure "nvidia-smi command is missing"
  fi

  # Free disk report / optional rejection threshold
  local free_kb=0
  local free_gb=0

  free_kb="$(df -Pk "$WORKSPACE" 2>/dev/null | awk 'NR==2 {print $4}' || echo 0)"
  if [[ "$free_kb" =~ ^[0-9]+$ ]]; then
    free_gb=$((free_kb / 1024 / 1024))
  fi

  log "[HOST CHECK] Free disk at $WORKSPACE: ${free_gb} GiB"

  if [[ "$PREFLIGHT_MIN_FREE_GB" =~ ^[0-9]+$ ]] \
    && [[ "$PREFLIGHT_MIN_FREE_GB" -gt 0 ]] \
    && [[ "$free_gb" -lt "$PREFLIGHT_MIN_FREE_GB" ]]; then
    preflight_record_failure \
      "free disk ${free_gb} GiB is below PREFLIGHT_MIN_FREE_GB=${PREFLIGHT_MIN_FREE_GB}"
  fi

  # DNS resolution
  local domain
  for domain in github.com huggingface.co pypi.org civitai.com region1.v2.argotunnel.com; do
    if getent hosts "$domain" >/dev/null 2>&1; then
      log "[HOST CHECK: OK] DNS: $domain"
    else
      preflight_record_failure "DNS lookup failed: $domain"
    fi
  done

  # GitHub: test the same Git smart-HTTP path used by git clone.
  preflight_retry_command \
    "GitHub git clone path" \
    bash -lc \
      'git -c http.version=HTTP/1.1 ls-remote https://github.com/ltdrdata/ComfyUI-Manager.git HEAD >/dev/null' \
    || true

  # Other services used by this provisioning script.
  preflight_https \
    "PyPI HTTPS" \
    "https://pypi.org/simple/pip/" || true

  preflight_https \
    "Hugging Face HTTPS" \
    "https://huggingface.co/api/models/Comfy-Org/MiniMax-H3" || true

  preflight_https \
    "Civitai HTTPS" \
    "https://civitai.com/api/v1/models?limit=1" || true

  local result_file="/workspace/host_preflight_result.txt"

  if [[ ${#PREFLIGHT_FAILURES[@]} -gt 0 ]]; then
    {
      echo "result=FAIL"
      echo "checked_at=$(date --iso-8601=seconds 2>/dev/null || date)"
      echo "free_disk_gib=$free_gb"
      echo "failures=${#PREFLIGHT_FAILURES[@]}"
      for x in "${PREFLIGHT_FAILURES[@]}"; do
        echo "- $x"
      done
    } > "$result_file"

    touch /workspace/HOST_PREFLIGHT_FAILED

    log "============================================================"
    log "HOST PREFLIGHT FAILED"
    for x in "${PREFLIGHT_FAILURES[@]}"; do
      log "  - $x"
    done
    log "Result file: $result_file"
    log "This host is unsuitable for this provisioning run."
    log "Destroy this Vast instance and choose another host."
    log "Provisioning aborted before custom-node/model downloads."
    log "============================================================"

    exit 90
  fi

  {
    echo "result=PASS"
    echo "checked_at=$(date --iso-8601=seconds 2>/dev/null || date)"
    echo "free_disk_gib=$free_gb"
    echo "failures=0"
  } > "$result_file"

  touch /workspace/HOST_PREFLIGHT_PASSED

  log "============================================================"
  log "HOST PREFLIGHT PASSED"
  log "Result file: $result_file"
  log "Continuing provisioning."
  log "============================================================"
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

provisioning_enable_hf_xet() {
  log "Enabling Hugging Face high-performance Xet downloads (best-effort)..."

  set +e
  pip_install -q huggingface_hub hf_xet
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log "huggingface_hub/hf_xet install failed. Continuing with aria2/wget/curl fallback."
  else
    unset HF_HUB_ENABLE_HF_TRANSFER || true
    export HF_XET_HIGH_PERFORMANCE=1
    log "HF Xet high-performance mode enabled"
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

  mkdir -p "$dir" "$HF_DOWNLOAD_TMP_DIR"

  log "HF direct attempt: repo=$repo_id rev=$rev file=$file_path -> $dir"
  log "HF temporary/resume directory: $HF_DOWNLOAD_TMP_DIR"

  set +e
  "$PYTHON_BIN" - "$repo_id" "$rev" "$file_path" "$dir" "$HF_DOWNLOAD_TMP_DIR" <<'PY'
import json
import os
import struct
import sys

repo_id, rev, file_path, out_dir, temp_dir = sys.argv[1:6]
token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_HUB_TOKEN") or None

try:
    from huggingface_hub import get_hf_file_metadata, hf_hub_download, hf_hub_url
except Exception as e:
    print("[provision] huggingface_hub not available:", repr(e))
    sys.exit(2)

os.makedirs(out_dir, exist_ok=True)
os.makedirs(temp_dir, exist_ok=True)

dst = os.path.join(out_dir, os.path.basename(file_path))
expected_size = None

try:
    metadata_url = hf_hub_url(
        repo_id=repo_id,
        filename=file_path,
        revision=rev,
    )
    metadata = get_hf_file_metadata(metadata_url, token=token)
    expected_size = metadata.size
except Exception as e:
    print("[provision] HF metadata check warning:", repr(e))

def valid_safetensors_file(path: str) -> bool:
    """Check that a safetensors header and its declared data exactly fit the file."""
    try:
        file_size = os.path.getsize(path)
        with open(path, "rb") as f:
            raw = f.read(8)
            if len(raw) != 8:
                return False

            header_size = struct.unpack("<Q", raw)[0]
            if header_size <= 0 or header_size > file_size - 8:
                return False

            header_raw = f.read(header_size)
            header = json.loads(header_raw)

        max_end = 0
        for key, value in header.items():
            if key == "__metadata__":
                continue
            offsets = value.get("data_offsets")
            if (
                not isinstance(offsets, list)
                or len(offsets) != 2
                or not all(isinstance(x, int) for x in offsets)
            ):
                return False
            start, end = offsets
            if start < 0 or end < start:
                return False
            max_end = max(max_end, end)

        return 8 + header_size + max_end == file_size
    except Exception:
        return False


if os.path.isfile(dst):
    actual_size = os.path.getsize(dst)

    if expected_size is not None and actual_size == expected_size:
        print(
            f"[provision] HF file already complete, skipping: "
            f"{dst} ({actual_size} bytes)"
        )
        sys.exit(0)

    # When the metadata request is temporarily unavailable, do not trust a file
    # merely because it is larger than 1 MB. Safetensors contains enough offset
    # information to detect a truncated file without loading model tensors.
    if expected_size is None and dst.endswith(".safetensors") and valid_safetensors_file(dst):
        print(
            f"[provision] HF metadata unavailable, but safetensors structure is complete; "
            f"skipping: {dst} ({actual_size} bytes)"
        )
        sys.exit(0)

    print(
        f"[provision] Existing HF file is incomplete, unverifiable, or mismatched; "
        f"re-downloading: {dst} "
        f"(actual={actual_size}, expected={expected_size})"
    )
    os.remove(dst)

try:
    downloaded_path = hf_hub_download(
        repo_id=repo_id,
        filename=file_path,
        revision=rev,
        token=token,
        local_dir=temp_dir,
    )

    downloaded_size = os.path.getsize(downloaded_path)

    if expected_size is not None and downloaded_size != expected_size:
        raise OSError(
            f"downloaded size mismatch: actual={downloaded_size}, "
            f"expected={expected_size}"
        )

    if downloaded_size < 1024 * 1024:
        raise OSError(f"downloaded file is too small: {downloaded_size} bytes")

    # Atomic rename on the same /workspace filesystem: no second full-size copy.
    os.replace(downloaded_path, dst)

    print(f"[provision] HF downloaded directly OK -> {dst}")
    print(f"[provision] HF final size: {downloaded_size} bytes")
    sys.exit(0)

except Exception as e:
    print("[provision] HF direct download failed:", repr(e))
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
    provisioning_configure_hf_runtime

    if provisioning_hf_transfer_download "$dir" "$final_url"; then
      validate_downloaded_file_in_dir "$dir" "$before_list" || true

      # The completed model has already been moved to its final ComfyUI folder.
      # Remove local_dir metadata and every contained Xet/HF cache immediately.
      provisioning_cleanup_hf_artifacts
      rm -f "$before_list"
      return 0
    else
      log "HF Python downloader failed. Removing its partial/cache data before fallback."
      provisioning_cleanup_hf_artifacts
      log "Falling back to an atomic aria2/wget/curl download."
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

  local final_path="${dir}/${name}"
  local part_name="${name}.part"
  local part_path="${dir}/${part_name}"

  set +e

  if command -v aria2c >/dev/null 2>&1; then
    if [[ -n "$auth_header" ]]; then
      aria2c \
        --continue=true \
        --auto-file-renaming=false \
        --allow-overwrite=true \
        -x 16 -s 16 -k 1M \
        --header="$auth_header" \
        -o "$part_name" -d "$dir" "$final_url"
    else
      aria2c \
        --continue=true \
        --auto-file-renaming=false \
        --allow-overwrite=true \
        -x 16 -s 16 -k 1M \
        -o "$part_name" -d "$dir" "$final_url"
    fi
    local rc=$?

  elif command -v wget >/dev/null 2>&1; then
    if [[ -n "$auth_header" ]]; then
      wget --continue --header="$auth_header" -O "$part_path" "$final_url"
    else
      wget --continue -O "$part_path" "$final_url"
    fi
    local rc=$?

  else
    if [[ -n "$auth_header" ]]; then
      curl -fL \
        --retry 5 \
        --retry-delay 5 \
        --retry-all-errors \
        -H "$auth_header" \
        -C - \
        -o "$part_path" \
        "$final_url"
    else
      curl -fL \
        --retry 5 \
        --retry-delay 5 \
        --retry-all-errors \
        -C - \
        -o "$part_path" \
        "$final_url"
    fi
    local rc=$?
  fi

  set -e

  if [[ $rc -ne 0 ]]; then
    rm -f "$before_list"
    return "$rc"
  fi

  if [[ ! -f "$part_path" ]]; then
    log "Fallback download reported success but part file is missing: $part_path"
    rm -f "$before_list"
    return 1
  fi

  local part_size
  part_size="$(stat -c%s "$part_path" 2>/dev/null || echo 0)"
  if [[ "$part_size" -lt 1048576 ]]; then
    log "Fallback download is too small: $part_path ($part_size bytes)"
    rm -f "$before_list"
    return 1
  fi

  mv -f -- "$part_path" "$final_path"

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
# FISH AUDIO S2 PRO MODEL PRELOAD
# ============================================================

provisioning_preload_fish_s2() {
  if [[ "$FISH_S2_PRELOAD" != "1" ]]; then
    log "Fish S2 preload disabled (FISH_S2_PRELOAD=$FISH_S2_PRELOAD)"
    return 0
  fi

  mkdir -p "$FISH_S2_MODEL_DIR"
  provisioning_configure_hf_runtime

  # FP8 repo layout: one ~6.16 GB model.safetensors plus ~1.87 GB codec.pth.
  local model_file="${FISH_S2_MODEL_DIR}/model.safetensors"
  local codec="${FISH_S2_MODEL_DIR}/codec.pth"
  local config="${FISH_S2_MODEL_DIR}/config.json"
  local quant_info="${FISH_S2_MODEL_DIR}/quantization_info.json"

  if [[ -s "$model_file" && -s "$codec" && -s "$config" && -s "$quant_info" ]]; then
    log "Fish S2 Pro FP8 model already present; skipping preload: $FISH_S2_MODEL_DIR"
    ls -lh "$model_file" "$codec" "$config" "$quant_info" || true
    return 0
  fi

  log "Preloading Fish S2 Pro FP8 repo: $FISH_S2_REPO"
  log "Destination: $FISH_S2_MODEL_DIR"

  set +e
  "$PYTHON_BIN" - "$FISH_S2_REPO" "$FISH_S2_MODEL_DIR" <<'PY'
import os
import sys

repo_id, out_dir = sys.argv[1:3]
token = os.environ.get("HF_TOKEN") or os.environ.get("HUGGINGFACE_HUB_TOKEN") or None

from huggingface_hub import snapshot_download

os.makedirs(out_dir, exist_ok=True)

# Download only files needed for inference. This avoids README/images/license extras.
snapshot_download(
    repo_id=repo_id,
    local_dir=out_dir,
    token=token,
    allow_patterns=[
        "config.json",
        "chat_template.jinja",
        "codec.pth",
        "model.safetensors",
        "quantization_info.json",
        "special_tokens_map.json",
        "tokenizer.json",
        "tokenizer_config.json",
    ],
)

print(f"[provision] Fish S2 FP8 preload complete -> {out_dir}")
PY
  local rc=$?
  set -e

  if [[ $rc -ne 0 ]]; then
    log "Fish S2 preload FAILED with rc=$rc"
    MODEL_DL_FAILS+=("$FISH_S2_REPO (Fish S2 preload)")
    provisioning_cleanup_hf_artifacts || true

    if [[ "$FAIL_ON_MODEL_DL" == "1" ]]; then
      exit "$rc"
    fi
    return 0
  fi

  # snapshot_download(local_dir=...) may create lightweight local metadata.
  rm -rf "${FISH_S2_MODEL_DIR}/.cache" || true
  provisioning_cleanup_hf_artifacts || true

  log "Fish S2 Pro FP8 files:"
  find "$FISH_S2_MODEL_DIR" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort || true
}


# ============================================================
# SAM 3.1 / EASY-SAM3 MODEL LINK
# ============================================================

provisioning_link_sam31_model() {
  local filename="sam3.1_multiplex_fp16.safetensors"
  local src="${COMFY_WORKSPACE}/models/checkpoints/${filename}"
  local sam3_dir="${COMFY_WORKSPACE}/models/sam3"
  local dst="${sam3_dir}/${filename}"

  mkdir -p "$sam3_dir"

  if [[ ! -f "$src" ]]; then
    log "SAM 3.1 source model missing; Easy-SAM3 symlink not created: $src"
    return 0
  fi

  local src_size
  src_size="$(stat -c%s "$src" 2>/dev/null || echo 0)"
  if [[ ! "$src_size" =~ ^[0-9]+$ ]] || [[ "$src_size" -lt 1048576 ]]; then
    log "SAM 3.1 source model looks invalid or incomplete; symlink not created: $src ($src_size bytes)"
    return 0
  fi

  # If an older provisioning run left a second physical copy here, replace only
  # this exact SAM 3.1 filename with a symlink so the 1.75 GB model is stored once.
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local dst_size
    dst_size="$(stat -c%s "$dst" 2>/dev/null || echo 0)"
    log "Replacing duplicate Easy-SAM3 SAM 3.1 copy with symlink: $dst ($dst_size bytes)"
    rm -f -- "$dst"
  fi

  ln -sfn "$src" "$dst"

  if [[ -L "$dst" && -e "$dst" ]]; then
    log "SAM 3.1 symlink ready: $dst -> $(readlink "$dst")"
    ls -lh "$src" "$dst" || true
  else
    log "WARNING: SAM 3.1 symlink verification failed: $dst"
  fi
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
  print_dir_summary "sam3" "${COMFY_WORKSPACE}/models/sam3"
  print_dir_summary "vae" "${COMFY_WORKSPACE}/models/vae"
  print_dir_summary "upscale_models" "${COMFY_WORKSPACE}/models/upscale_models"
  print_dir_summary "diffusion_models" "${COMFY_WORKSPACE}/models/diffusion_models"
  print_dir_summary "text_encoders" "${COMFY_WORKSPACE}/models/text_encoders"

  local checkpoint_count
  checkpoint_count="$(find "${COMFY_WORKSPACE}/models/checkpoints" -maxdepth 1 -type f \( -name "*.safetensors" -o -name "*.ckpt" \) ! -name "sam3.1_multiplex_fp16.safetensors" | wc -l || true)"

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

  provisioning_cleanup_legacy_hf_cache
  provisioning_cleanup_hf_artifacts
  trap provisioning_hf_exit_cleanup EXIT

  provisioning_get_apt_packages
  provisioning_host_preflight
  provisioning_get_nodes
  provisioning_get_pip_packages

  provisioning_enable_hf_xet

  # Fresh Vast instances: download the FP8 S2 Pro repo during provisioning so
  # the first ComfyUI generation does not have to fetch the ~8 GB repo.
  provisioning_preload_fish_s2

  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/checkpoints"      "${CHECKPOINT_MODELS[@]}"
  provisioning_get_models_dir_urlonly "${COMFY_WORKSPACE}/models/checkpoints"      "${SAM31_MODELS[@]}"
  provisioning_link_sam31_model

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
