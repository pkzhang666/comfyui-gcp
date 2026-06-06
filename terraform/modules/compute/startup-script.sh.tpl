#!/bin/bash
# ComfyUI startup script — runs on every VM boot, idempotent
set -e

COMFYUI_DIR="/opt/comfyui"
COMFYUI_PORT="${comfyui_port}"
COMFYUI_LISTEN="${comfyui_listen}"
COMFYUI_ARGS="${comfyui_args}"
DATA_DISK_MOUNT="/mnt/disks/models"
MODELS_BUCKET="${models_bucket}"
OUTPUTS_BUCKET="${outputs_bucket}"
LLAMA_PORT="${llama_port}"
LLM_MODEL_QUANT="${llm_model_quant}"
LLM_CONTEXT_SIZE="${llm_context_size}"
WEBUI_PORT="${webui_port}"
LOG_FILE="/var/log/comfyui-init.log"

exec >> "$LOG_FILE" 2>&1
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Boot startup triggered"

# Quick path for subsequent boots — start all already-configured services and exit
if [ -f "/etc/comfyui-initialized" ] && [ -f "/etc/llama-initialized" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] All services initialized — starting ComfyUI, llama-server and open-webui"
  systemctl start comfyui || true
  systemctl start llama-server || true
  docker start open-webui 2>/dev/null || true
  exit 0
elif [ -f "/etc/comfyui-initialized" ] && [ ! -f "/etc/llama-initialized" ]; then
  # ComfyUI already done; resume llama.cpp setup
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Resuming llama.cpp setup..."
  systemctl start comfyui || true
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] First boot — starting full initialization"

# ── 1. Wait for NVIDIA drivers (Deep Learning VM installs on first boot) ────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting for NVIDIA drivers..."
for i in $(seq 1 60); do
  if nvidia-smi &>/dev/null; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] nvidia-smi OK after $i attempts"
    break
  fi
  sleep 10
done
nvidia-smi || echo "WARNING: nvidia-smi failed — check GPU drivers"

# ── 2. System dependencies ──────────────────────────────────────────────────
apt-get update -y -q
apt-get install -y -q git python3 python3-pip python3-venv wget curl ffmpeg libgl1

# ── 3. Mount persistent data disk ───────────────────────────────────────────
DATA_DEVICE="/dev/disk/by-id/google-models-disk"
if [ -b "$DATA_DEVICE" ]; then
  REAL_DEVICE=$(readlink -f "$DATA_DEVICE")
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found data disk at $REAL_DEVICE"

  # Format on first use if no filesystem present
  if ! blkid "$REAL_DEVICE" | grep -q "TYPE="; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Formatting data disk..."
    mkfs.ext4 -F "$REAL_DEVICE"
  fi

  mkdir -p "$DATA_DISK_MOUNT"
  DISK_UUID=$(blkid -s UUID -o value "$REAL_DEVICE")
  if ! grep -q "$DISK_UUID" /etc/fstab; then
    echo "UUID=$DISK_UUID $DATA_DISK_MOUNT ext4 defaults,nofail 0 2" >> /etc/fstab
  fi
  mount -a
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Data disk mounted at $DATA_DISK_MOUNT"
else
  echo "WARNING: Data disk not found at $DATA_DEVICE — using boot disk for models"
  DATA_DISK_MOUNT="$COMFYUI_DIR"
fi

# ── 4. Clone ComfyUI ─────────────────────────────────────────────────────────
if [ ! -d "$COMFYUI_DIR/.git" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cloning ComfyUI..."
  git clone https://github.com/comfyanonymous/ComfyUI "$COMFYUI_DIR"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ComfyUI already cloned"
fi

cd "$COMFYUI_DIR"

# ── 5. Python virtual environment ───────────────────────────────────────────
if [ ! -d "$COMFYUI_DIR/venv" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating virtual environment..."
  python3 -m venv "$COMFYUI_DIR/venv"
fi

source "$COMFYUI_DIR/venv/bin/activate"

# ── 6. PyTorch with CUDA 12.1 ───────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing/verifying PyTorch CUDA..."
pip install --quiet --upgrade torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
python3 -c "import torch; print('[torch] CUDA available:', torch.cuda.is_available(), '| Device:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"

# ── 7. ComfyUI requirements ──────────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing ComfyUI requirements..."
pip install --quiet -r requirements.txt

# ── 8. ComfyUI Manager (node manager plugin) ─────────────────────────────────
MANAGER_DIR="$COMFYUI_DIR/custom_nodes/ComfyUI-Manager"
if [ ! -d "$MANAGER_DIR" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing ComfyUI-Manager..."
  git clone https://github.com/ltdrdata/ComfyUI-Manager.git "$MANAGER_DIR"
  pip install --quiet -r "$MANAGER_DIR/requirements.txt"
fi

# ── 9. Custom nodes ───────────────────────────────────────────────────────────
install_node() {
  local name="$1"
  local url="$2"
  local pin="$3"  # optional commit to pin to
  local dir="$COMFYUI_DIR/custom_nodes/$name"
  if [ ! -d "$dir" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing $name..."
    git clone "$url" "$dir"
    if [ -n "$pin" ]; then
      git -C "$dir" checkout "$pin"
    fi
    if [ -f "$dir/requirements.txt" ]; then
      pip install --quiet -r "$dir/requirements.txt" 2>/dev/null || true
    fi
  fi
}

install_node "ComfyUI-VideoHelperSuite"         "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
install_node "ComfyUI-AnimateDiff-Evolved"      "https://github.com/Kosinkadink/ComfyUI-AnimateDiff-Evolved"
install_node "ComfyUI-Custom-Scripts"           "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
install_node "ComfyUI-Easy-Use"                 "https://github.com/yolain/ComfyUI-Easy-Use"
install_node "ComfyUI-Frame-Interpolation"      "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation"
install_node "ComfyUI-GGUF"                     "https://github.com/city96/ComfyUI-GGUF"
install_node "ComfyUI-Impact-Pack"              "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
install_node "ComfyUI-Impact-Subpack"           "https://github.com/ltdrdata/ComfyUI-Impact-Subpack"
install_node "ComfyUI-InstantX-IPAdapter-SD3"   "https://github.com/Slickytail/ComfyUI-InstantX-IPAdapter-SD3"
install_node "ComfyUI-KJNodes"                  "https://github.com/kijai/ComfyUI-KJNodes"
install_node "ComfyUI-LoRA-stacker"             "https://github.com/zwaigani/ComfyUI-LoRA-stacker"
install_node "ComfyUI-Lora-Manager"             "https://github.com/willmiao/ComfyUI-Lora-Manager.git"
install_node "ComfyUI-ReActor"                  "https://github.com/Gourieff/ComfyUI-ReActor"
install_node "ComfyUI-WanVideoWrapper"          "https://github.com/kijai/ComfyUI-WanVideoWrapper"
install_node "ComfyUI-quadMoons-nodes"          "https://github.com/traugdor/ComfyUI-quadMoons-nodes"
install_node "ComfyUI_IPAdapter_plus"           "https://github.com/cubiq/ComfyUI_IPAdapter_plus" "93d973a"
install_node "ComfyUI_essentials"               "https://github.com/cubiq/ComfyUI_essentials"
install_node "SeargeSDXL"                       "https://github.com/SeargeDP/SeargeSDXL"
install_node "cg-use-everywhere"                "https://github.com/chrisgoringe/cg-use-everywhere"
install_node "comfyui-animatediff"              "https://github.com/SipherAGI/comfyui-animatediff"
install_node "comfyui-tooling-nodes"            "https://github.com/Acly/comfyui-tooling-nodes.git"
install_node "efficiency-nodes-comfyui"         "https://github.com/jags111/efficiency-nodes-comfyui"
install_node "rgthree-comfy"                    "https://github.com/rgthree/rgthree-comfy"

# ── 10. Set up model directories on data disk ─────────────────────────────────
if mountpoint -q "$DATA_DISK_MOUNT" 2>/dev/null || [ "$DATA_DISK_MOUNT" != "$COMFYUI_DIR" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up model directories..."
  for subdir in checkpoints vae loras controlnet upscale_models clip unet diffusion_models text_encoders clip_vision animatediff_models video_formats latent_upscale_models GGUF sams ipadapter embeddings; do
    mkdir -p "$DATA_DISK_MOUNT/models/$subdir"
  done
  mkdir -p "$DATA_DISK_MOUNT/output"
  mkdir -p "$DATA_DISK_MOUNT/input"

  # Replace ComfyUI's default dirs with symlinks to the data disk
  for dir in models output input; do
    rm -rf "$COMFYUI_DIR/$dir"
    ln -sfn "$DATA_DISK_MOUNT/$dir" "$COMFYUI_DIR/$dir"
  done
fi

# ── 11. Download models ──────────────────────────────────────────────────────
download_model() {
  local subdir="$1"
  local url="$2"
  local filename
  filename="$(basename "$url" | cut -d'?' -f1)"
  local dest="$DATA_DISK_MOUNT/models/$subdir/$filename"
  if [ -f "$dest" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Already exists, skipping: $filename"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading $subdir/$filename..."
    wget -q -O "$dest" "$url" || { rm -f "$dest"; echo "ERROR: failed to download $filename"; }
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done: $filename"
  fi
}

download_model "checkpoints"           "https://huggingface.co/Lightricks/LTX-2.3-fp8/resolve/main/ltx-2.3-22b-dev-fp8.safetensors"
download_model "latent_upscale_models" "https://huggingface.co/Lightricks/LTX-2.3/resolve/main/ltx-2.3-spatial-upscaler-x2-1.1.safetensors"
download_model "loras"                 "https://huggingface.co/Comfy-Org/ltx-2.3/resolve/main/split_files/loras/ltx_2.3_22b_distilled_1.1_lora_dynamic_fro09_avg_rank_111_bf16.safetensors"
download_model "loras"                 "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/loras/gemma-3-12b-it-abliterated_lora_rank64_bf16.safetensors"
download_model "text_encoders"         "https://huggingface.co/Comfy-Org/ltx-2/resolve/main/split_files/text_encoders/gemma_3_12B_it_fp4_mixed.safetensors"
download_model "checkpoints"           "https://huggingface.co/SulphurAI/Sulphur-2-base/resolve/main/sulphur_dev_bf16.safetensors?download=true"

# ── 12. extra_model_paths.yaml ────────────────────────────────────────────────
cat > "$COMFYUI_DIR/extra_model_paths.yaml" << YAML
comfyui:
    base_path: $DATA_DISK_MOUNT/
    checkpoints: models/checkpoints/
    vae: models/vae/
    loras: models/loras/
    upscale_models: models/upscale_models/
    embeddings: models/embeddings/
    clip: models/clip/
    clip_vision: models/clip_vision/
    unet: models/unet/
    diffusion_models: models/diffusion_models/
    text_encoders: models/text_encoders/
    animatediff_models: models/animatediff_models/
    video_formats: models/video_formats/
    latent_upscale_models: models/latent_upscale_models/
    GGUF: models/GGUF/
    sams: models/sams/
    ipadapter: models/ipadapter/
YAML

# ── 13. systemd service ───────────────────────────────────────────────────────
cat > /etc/systemd/system/comfyui.service << SERVICE
[Unit]
Description=ComfyUI Image-to-Video Workflow
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$COMFYUI_DIR
ExecStart=$COMFYUI_DIR/venv/bin/python main.py --listen $COMFYUI_LISTEN --port $COMFYUI_PORT $COMFYUI_ARGS
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
Environment="HOME=/root"
Environment="PATH=$COMFYUI_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable comfyui
systemctl start comfyui

touch /etc/comfyui-initialized
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ComfyUI initialization complete — listening on port $COMFYUI_PORT"

# ── llama.cpp + Qwen3.6-35B setup ────────────────────────────────────────────
if [ ! -f "/etc/llama-initialized" ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Starting llama.cpp setup ==="

  LLAMA_DIR="/opt/llama.cpp"
  LLM_MODEL_DIR="$DATA_DISK_MOUNT/llm"
  MODEL_REPO="HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive"
  MODEL_FILE="Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-$LLM_MODEL_QUANT.gguf"
  MMPROJ_FILE="mmproj-Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive-f16.gguf"
  HF_BASE="https://huggingface.co/$MODEL_REPO/resolve/main"

  # Extra build dependencies
  apt-get install -y -q cmake build-essential libcurl4-openssl-dev

  # Ensure nvcc is on PATH (Deep Learning VMs install CUDA to /usr/local/cuda)
  export PATH=/usr/local/cuda/bin:$PATH
  export CUDA_HOME=/usr/local/cuda

  # Clone llama.cpp
  if [ ! -d "$LLAMA_DIR/.git" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cloning llama.cpp..."
    git clone https://github.com/ggml-org/llama.cpp "$LLAMA_DIR"
  else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating llama.cpp..."
    git -C "$LLAMA_DIR" pull --ff-only 2>/dev/null || true
  fi

  # Build with CUDA (A100 = SM 80) — explicitly set nvcc path
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Building llama.cpp with CUDA SM_80 (A100)..."
  cmake -B "$LLAMA_DIR/build" "$LLAMA_DIR" \
    -DGGML_CUDA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=80 \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_CURL=ON \
    -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc \
    2>&1 | tee /var/log/llama-cmake.log
  cmake --build "$LLAMA_DIR/build" --config Release -j$(nproc) \
    2>&1 | tee /var/log/llama-build.log
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] llama.cpp build complete"

  # Download model (resumable with -c)
  mkdir -p "$LLM_MODEL_DIR"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading $MODEL_FILE from HuggingFace..."
  wget -c -q --show-progress \
    -O "$LLM_MODEL_DIR/$MODEL_FILE" \
    "$HF_BASE/$MODEL_FILE" \
    || echo "WARNING: model download may be incomplete"

  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Downloading vision projector $MMPROJ_FILE..."
  wget -c -q --show-progress \
    -O "$LLM_MODEL_DIR/$MMPROJ_FILE" \
    "$HF_BASE/$MMPROJ_FILE" \
    || echo "WARNING: mmproj download may be incomplete"

  # systemd service for llama-server
  # Note: ExecStart must be a single line — multi-line with backslash continuation
  # causes systemd to mis-parse arguments (e.g. --flash-attn sees next flag as its value)
  cat > /etc/systemd/system/llama-server.service << SERVICE
[Unit]
Description=llama.cpp Server — Qwen3.6-35B-A3B ($LLM_MODEL_QUANT)
After=network.target

[Service]
Type=simple
User=root
ExecStart=$LLAMA_DIR/build/bin/llama-server --model $LLM_MODEL_DIR/$MODEL_FILE --mmproj $LLM_MODEL_DIR/$MMPROJ_FILE --host 0.0.0.0 --port $LLAMA_PORT -ngl 99 --ctx-size $LLM_CONTEXT_SIZE --flash-attn on --parallel 4
Restart=on-failure
RestartSec=15
StandardOutput=journal
StandardError=journal
Environment=HOME=/root
Environment=PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=CUDA_HOME=/usr/local/cuda

[Install]
WantedBy=multi-user.target
SERVICE

  systemctl daemon-reload
  systemctl enable llama-server
  systemctl start llama-server
  touch /etc/llama-initialized
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] llama-server initialized on port $LLAMA_PORT"
fi

# ── Open WebUI ────────────────────────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Setting up Open WebUI..."

# Install Docker if not present
if ! command -v docker &>/dev/null; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi

# Pull image once, then start container (idempotent)
if ! docker inspect open-webui &>/dev/null; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting Open WebUI container..."
  docker run -d \
    --name open-webui \
    --restart always \
    -v open-webui:/app/backend/data \
    -e ENABLE_OLLAMA_API=false \
    -e OPENAI_API_BASE_URL=http://localhost:$LLAMA_PORT/v1 \
    -e OPENAI_API_KEY=none \
    -e WEBUI_AUTH=false \
    -e PORT=$WEBUI_PORT \
    -e ENABLE_WEB_SEARCH=true \
    -e WEB_SEARCH_ENGINE=duckduckgo \
    -e WEB_SEARCH_RESULT_COUNT=5 \
    -e WEB_SEARCH_CONCURRENT_REQUESTS=10 \
    -e USER_PERMISSIONS_FEATURES_WEB_SEARCH=true \
    -e BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL=true \
    -e BYPASS_WEB_SEARCH_WEB_LOADER=true \
    --network host \
    ghcr.io/open-webui/open-webui:main
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Open WebUI started on port $WEBUI_PORT"
else
  docker start open-webui 2>/dev/null || true
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Open WebUI already exists, started"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All initialization complete"
