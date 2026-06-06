# Image-to-Video Workflow

Image-to-video (I2V) takes a **still image as input** and generates a short video clip where the scene comes alive — camera movement, character animation, wind in hair, water flowing, etc.

## Supported Models

| Model | Output Resolution | Clip Length | VRAM (T4) | Quality |
|-------|------------------|-------------|-----------|---------|
| **Wan2.1 I2V 14B** | 480p / 720p | ~81 frames (~3s) | 14–16 GB | ⭐⭐⭐⭐⭐ Best |
| **SVD-XT** | 576×1024 | 25 frames (~1s) | 14–16 GB | ⭐⭐⭐⭐ |
| **SVD** (base) | 576×1024 | 14 frames | 12 GB | ⭐⭐⭐ |
| **AnimateDiff** | 512×512–768×768 | 16–32 frames | 8–12 GB | ⭐⭐⭐ |
| **CogVideoX-5B** | 480×720 | 49 frames (~6s) | 16+ GB | ⭐⭐⭐⭐ |

**Recommendation for T4:** Start with **SVD-XT** (easiest setup), then try **Wan2.1** for better quality.

---

## Workflow A — Stable Video Diffusion (SVD-XT)

SVD is the simplest I2V model to set up and produces very stable, realistic motion.

### Setup

```bash
make ssh

# Download SVD-XT (25 frames, ~9.9 GB)
cd /mnt/disks/models/models/checkpoints
wget "https://huggingface.co/stabilityai/stable-video-diffusion-img2vid-xt/resolve/main/svd_xt.safetensors"
```

### Workflow in ComfyUI

1. **Load the SVD workflow** — in ComfyUI, go to **Load** → paste or load this workflow structure:

   ```
   [Load Image] ──────────────────────────┐
                                           ↓
   [Load Checkpoint: svd_xt.safetensors] → [Stable Video Diffusion]
                                           ↓
   [Video Combine] ← [VAE Decode Tiled]  ←┘
         ↓
   [Save Video]
   ```

2. **Step by step:**
   - Add **Load Image** node → upload your source image (ideally 576×1024 or 1024×576)
   - Add **Load Checkpoint** → select `svd_xt.safetensors`
   - Add **SVD Img2Vid Conditioning** node with settings:
     - `augmentation_level`: 0 (0 = keep image faithful)
     - `motion_bucket_id`: 100–150 (higher = more motion)
     - `fps`: 6
   - Add **KSampler** (or **Video KSampler**):
     - `steps`: 20–25
     - `cfg`: 2.5 (SVD uses very low CFG!)
     - `sampler`: `euler`
   - Add **VAE Decode Tiled** (for memory efficiency)
   - Add **Video Combine** (from VideoHelperSuite) → set fps, format
   - Click **Queue Prompt**

3. **Output:** A video file saved to `/mnt/disks/models/output/`

### SVD Parameters

| Parameter | Value | Effect |
|-----------|-------|--------|
| `motion_bucket_id` | 100 | Subtle motion |
| `motion_bucket_id` | 200 | Strong motion |
| `augmentation_level` | 0.0 | Keep image colors exact |
| `augmentation_level` | 0.1 | Slight variation, more natural |
| `fps` | 6 | Output frame rate |
| `steps` | 20 | Quality vs speed |

---

## Workflow B — Wan2.1 (Best Quality) {#wan21-setup}

Wan2.1 is currently the best open-source image-to-video model. It requires more setup.

### Setup

```bash
make ssh

# Install HuggingFace CLI
pip install huggingface_hub

# Login (create token at https://huggingface.co/settings/tokens)
huggingface-cli login

# Download Wan2.1 I2V 480P model (~14 GB — takes 20-30 min on VM)
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
  --local-dir /mnt/disks/models/models/unet/wan2.1-i2v-480p \
  --include "*.safetensors" "*.json"

# Download required CLIP model
cd /mnt/disks/models/models/clip
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
  --local-dir . \
  --include "clip_vision_h.safetensors"

# Download VAE
cd /mnt/disks/models/models/vae
huggingface-cli download Wan-AI/Wan2.1-I2V-14B-480P \
  --local-dir . \
  --include "wan_2.1_vae.safetensors"
```

### Required Custom Nodes

In ComfyUI → **Manager** → **Install Custom Nodes**:
- Search and install: **ComfyUI-WanVideoWrapper** (or the official Wan2.1 node pack)

Alternatively via SSH:
```bash
cd /opt/comfyui/custom_nodes
git clone https://github.com/kijai/ComfyUI-WanVideoWrapper.git
cd ComfyUI-WanVideoWrapper
pip install -r requirements.txt
sudo systemctl restart comfyui
```

### Workflow in ComfyUI

```
[Load Image] ──────────────────────────────────┐
                                                ↓
[Load WanVideo Model] → [WanVideo I2V Encode] → [WanVideo Sampler]
                                                ↓
                        [WanVideo VAE Decode] ←─┘
                                ↓
                        [Video Combine]
                                ↓
                        [Save Video]
```

Key settings:
- `num_frames`: 81 (≈3 seconds at 24fps)
- `steps`: 20–30
- `cfg`: 6–8
- `width/height`: 832×480 (for 480P model)

### Wan2.1 Prompting

Unlike image-only models, Wan2.1 benefits from **motion prompts**:

```
# Positive prompt — describe what should happen:
"the woman's hair flowing gently in the breeze, camera slowly zooming in, cinematic"

# Negative prompt:
"static, no movement, blurry, distorted"
```

---

## Workflow C — AnimateDiff (Longer Animations)

AnimateDiff runs on top of SD 1.5 checkpoints — you can animate any SD-compatible image style.

### Setup

```bash
# AnimateDiff motion module
cd /mnt/disks/models/models/animatediff_models
wget "https://huggingface.co/guoyww/animatediff/resolve/main/v3_sd15_mm.ckpt"

# Also need an SD 1.5 checkpoint
cd /mnt/disks/models/models/checkpoints
wget "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"
```

Install custom node via Manager: **ComfyUI-AnimateDiff-Evolved**

### How It Works

AnimateDiff adds temporal consistency across frames — it doesn't start from an image, it animates a text prompt across 16–32 frames.

```
[Load Checkpoint: SD1.5] → [AnimateDiff Loader: v3_sd15_mm.ckpt]
        ↓                            ↓
[CLIP Text Encode] ──────────────→ [KSampler]
                                       ↓
                               [VAE Decode]
                                       ↓
                               [Video Combine]
```

Key parameters:
- `context_length`: 16 (frames processed at once, limited by VRAM)
- `context_stride`: 1
- `video_length`: 16–32 frames

---

## Preparing Your Input Image

Image quality directly affects video quality:

| Tip | Why |
|-----|-----|
| Use 16:9 or 9:16 aspect ratio | Models are trained on these ratios |
| Min 512×512 resolution | Anything smaller gets upscaled and loses quality |
| Clear subject, simple background | Complex backgrounds cause artifacts |
| No text or watermarks | These look weird in motion |
| Well-lit, not dark | Models handle brightness better |

**Resize your image before upload:**
```bash
# Upload to VM input folder
gsutil cp your-image.jpg gs://$MODELS_BUCKET/inputs/

# Or directly via SSH SCP:
gcloud compute scp your-image.jpg comfyui-vm:/mnt/disks/models/input/ \
  --zone=us-central1-a --project=$PROJECT_ID --tunnel-through-iap
```

---

## Saving and Downloading Your Video

Generated videos save to `/mnt/disks/models/output/` on the VM.

**Download to your local machine:**

```bash
# Via gcloud SCP
gcloud compute scp comfyui-vm:/mnt/disks/models/output/your-video.mp4 . \
  --zone=us-central1-a --project=$PROJECT_ID --tunnel-through-iap

# Or upload to GCS first, then download from there
# (On VM)
gsutil cp /mnt/disks/models/output/*.mp4 gs://$OUTPUTS_BUCKET/

# (On local machine)
gsutil cp gs://$OUTPUTS_BUCKET/*.mp4 ./downloads/
```

---

## Typical Generation Times on T4

| Model | Frames | Steps | Time |
|-------|--------|-------|------|
| SVD-XT | 25 | 20 | ~3–4 min |
| Wan2.1 480P | 81 | 20 | ~8–12 min |
| AnimateDiff | 16 | 20 | ~2–3 min |
| CogVideoX-5B | 49 | 50 | ~15–20 min |

Lower `steps` = faster but lower quality. Below 15 steps tends to look bad.
