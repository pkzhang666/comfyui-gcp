# Models Guide — How to Download, Install, and Manage Models

## Model Directory Structure

All models live on the 500 GB data disk mounted at `/mnt/disks/models/`. ComfyUI reads from these directories automatically:

```
/mnt/disks/models/
├── models/
│   ├── checkpoints/     ← Main model files (SD 1.5, SDXL, etc.)
│   ├── vae/             ← VAE files for image quality
│   ├── loras/           ← LoRA adapters (style modifiers)
│   ├── controlnet/      ← ControlNet models (guided generation)
│   ├── upscale_models/  ← Upscaler models (ESRGAN, etc.)
│   ├── clip/            ← CLIP text encoders (used by Flux)
│   ├── unet/            ← UNet weights (used by Flux, Wan2.1)
│   ├── animatediff_models/ ← AnimateDiff motion modules
│   └── video_formats/   ← Video format configs for AnimateDiff
├── output/              ← Generated images and videos
└── input/               ← Input images for img2img / video workflows
```

---

## Method 1 — Download Directly on the VM (Fastest)

```bash
# SSH into the VM
make ssh

# Navigate to the right directory
cd /mnt/disks/models/models/checkpoints

# Download with wget (keeps running even if your SSH disconnects)
# Use screen or tmux for large downloads
screen -S download
wget -c "https://huggingface.co/..." -O my-model.safetensors
# Ctrl+A, D to detach; screen -r download to reattach
```

---

## Method 2 — Upload from Your Local Machine via GCS

For models you already have locally, upload to GCS then pull onto the VM:

```bash
# From your local machine — upload to GCS models bucket
gsutil -m cp ./my-model.safetensors gs://$MODELS_BUCKET/checkpoints/

# SSH into VM and pull from GCS
make ssh
gsutil cp gs://$MODELS_BUCKET/checkpoints/my-model.safetensors \
  /mnt/disks/models/models/checkpoints/
```

For an entire folder of models:
```bash
# Local → GCS
gsutil -m cp -r ./models/ gs://$MODELS_BUCKET/

# GCS → VM
gsutil -m cp -r gs://$MODELS_BUCKET/ /mnt/disks/models/models/
```

---

## Method 3 — ComfyUI Manager (GUI)

In the ComfyUI browser interface:
1. Click **Manager** (top menu)
2. Click **Install Models**
3. Search for a model name
4. Click **Install** — it downloads directly to the correct folder

This works for many popular models but not all.

---

## Essential Models to Download

### For Image-to-Video (Primary Use Case)

See the full workflow guide at [image-to-video.md](image-to-video.md). Quick summary:

| Model | Size | VRAM | Best For |
|-------|------|------|----------|
| **Wan2.1-I2V-14B-480P** | ~14 GB | 14–16 GB | Best quality i2v, 480p output |
| **Wan2.1-I2V-14B-720P** | ~14 GB | 16+ GB | 720p output (tight on T4) |
| **Stable Video Diffusion (SVD)** | 9.9 GB | 14–16 GB | Short clips (14–25 frames), very stable |
| **AnimateDiff v3** | 1.8 GB | 8–12 GB | Longer animations, runs on top of SD 1.5 |

```bash
# Stable Video Diffusion (SVD-XT, 25 frames)
cd /mnt/disks/models/models/checkpoints
wget "https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt.safetensors"

# AnimateDiff v3 motion module
cd /mnt/disks/models/models/animatediff_models
wget "https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt"
```

For Wan2.1, see the full [Image-to-Video Workflow](image-to-video.md#wan21-setup).

### For Text-to-Image / Image-to-Image

```bash
cd /mnt/disks/models/models/checkpoints

# SD 1.5 — good starting point (~2 GB)
wget "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"

# SDXL Base — higher quality (~6.5 GB)
wget "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"
```

### VAE (Recommended for All SD Models)

```bash
cd /mnt/disks/models/models/vae

# For SD 1.5 — fixes washed-out colors
wget "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors"

# For SDXL — fixes color saturation
wget "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors"
```

---

## Flux Models {#flux}

Flux uses a different file structure — the main weights go in `unet/` instead of `checkpoints/`:

```bash
# Requires accepting license on HuggingFace first:
# https://huggingface.co/black-forest-labs/FLUX.1-dev

# UNet weights (~17 GB for fp8, fits T4)
cd /mnt/disks/models/models/unet
# Download flux1-dev-fp8.safetensors from HuggingFace

# CLIP text encoders
cd /mnt/disks/models/models/clip
# Download clip_l.safetensors
# Download t5xxl_fp16.safetensors (or t5xxl_fp8 to save VRAM)

# VAE
cd /mnt/disks/models/models/vae
# Download ae.safetensors
```

Use the **Flux workflow** from the ComfyUI examples — the node structure is different from SD.

---

## Refreshing Models in ComfyUI

After adding a new model file, ComfyUI doesn't automatically detect it. To refresh:

**Option A** — Click the refresh button on the node's model dropdown  
**Option B** — In Manager → click **Refresh** in the top toolbar  
**Option C** — Restart ComfyUI:
```bash
make ssh
sudo systemctl restart comfyui
```

---

## Checking Disk Usage

```bash
make ssh

# Overall disk usage
df -h /mnt/disks/models

# Models breakdown by folder
du -sh /mnt/disks/models/models/*

# Largest files
find /mnt/disks/models/models -name "*.safetensors" -o -name "*.ckpt" | \
  xargs ls -lh 2>/dev/null | sort -k5 -rh | head -20
```

---

## Backup Models to GCS

Models are large and expensive to re-download. Keep a copy in GCS:

```bash
# Sync all models to GCS (skips files already there)
gsutil -m rsync -r /mnt/disks/models/models gs://$MODELS_BUCKET/models/

# Restore from GCS to a new/rebuilt VM
gsutil -m rsync -r gs://$MODELS_BUCKET/models/ /mnt/disks/models/models/
```

---

## HuggingFace CLI (for gated models)

Some models (Wan2.1, Flux) require logging in to HuggingFace:

```bash
make ssh

# Install HuggingFace CLI
pip install huggingface_hub

# Login (generates a token at https://huggingface.co/settings/tokens)
huggingface-cli login

# Download a gated model
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
  --local-dir /mnt/disks/models/models/unet/wan2.1-i2v-480p
```
