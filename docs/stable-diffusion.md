# Stable Diffusion — What It Is and Which Version to Use

## Does ComfyUI Have Stable Diffusion?

ComfyUI **does not come with any models pre-installed** — it is a runner/interface, not a model itself. You download Stable Diffusion (or other models) separately and place them in the `models/checkpoints/` directory.

Think of it like this:
- **ComfyUI** = the engine and dashboard
- **Stable Diffusion** = the fuel (model weights you download)

ComfyUI supports many model families, not just Stable Diffusion.

---

## What is Stable Diffusion?

Stable Diffusion (SD) is an open-source AI image generation model developed by Stability AI. It converts text prompts (and optionally input images) into images using a process called **diffusion** — starting from random noise and gradually denoising toward a coherent image.

ComfyUI runs Stable Diffusion locally on your GPU. No API calls, no rate limits, no per-image fees.

---

## Model Versions Comparison

| Version | VRAM | Resolution | Best For | Download Size |
|---------|------|------------|----------|---------------|
| **SD 1.5** | 4–6 GB | 512×512 | General use, largest model ecosystem | ~2 GB |
| **SDXL** | 8–10 GB | 1024×1024 | High quality, more detail | ~6.5 GB |
| **SDXL Turbo** | 8 GB | 512×512 | Fast generation (1–4 steps) | ~6.5 GB |
| **SD 3 Medium** | 10–12 GB | 1024×1024 | Best text rendering, modern architecture | ~5 GB |
| **Flux.1 Dev** | 12–16 GB | 1024×1024 | State-of-the-art quality (2024) | ~23 GB |
| **Flux.1 Schnell** | 12–16 GB | 1024×1024 | Fast Flux (4 steps) | ~23 GB |

### Recommendation for T4 (16 GB VRAM)

| Use Case | Recommended Model |
|----------|------------------|
| Starting out / experimenting | **SD 1.5** (fast, small, huge ecosystem) |
| High quality stills | **SDXL** or **SD 3 Medium** |
| Best possible quality | **Flux.1 Dev** (fits on T4 with fp8 quantization) |
| Image-to-video | See [Image-to-Video Guide](image-to-video.md) |

---

## SD 1.5 — The Best Starting Point

SD 1.5 is the most widely supported version. It has:
- Thousands of fine-tuned variants on CivitAI (anime, photorealistic, art styles, etc.)
- The largest library of LoRAs and ControlNet models
- Runs fast on T4

**Download:**
```bash
make ssh
cd /mnt/disks/models/models/checkpoints

# Official SD 1.5
wget "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors"

# Popular realistic variant (RealisticVision)
wget "https://civitai.com/api/download/models/130072" -O realisticVision_v60B1.safetensors
```

---

## SDXL — Higher Quality

SDXL generates 1024×1024 images with much more detail. Uses more VRAM.

```bash
cd /mnt/disks/models/models/checkpoints

# SDXL Base (required)
wget "https://huggingface.co/stabilityai/stable-diffusion-xl-base-1.0/resolve/main/sd_xl_base_1.0.safetensors"

# SDXL Refiner (optional — adds detail in a second pass)
wget "https://huggingface.co/stabilityai/stable-diffusion-xl-refiner-1.0/resolve/main/sd_xl_refiner_1.0.safetensors"
```

SDXL also needs a VAE. Download and put in `models/vae/`:
```bash
cd /mnt/disks/models/models/vae
wget "https://huggingface.co/madebyollin/sdxl-vae-fp16-fix/resolve/main/sdxl_vae.safetensors"
```

---

## Flux.1 — State of the Art (2024–2025)

Flux produces stunning images but requires 12–16 GB VRAM. Works on T4 with fp8 quantization.

```bash
# Flux uses a different node structure in ComfyUI — use the Flux-specific workflow
# Models go in models/unet/ (not checkpoints/)

cd /mnt/disks/models/models/unet
# Download flux1-dev-fp8.safetensors (~17 GB) from Hugging Face
# Requires accepting license at: https://huggingface.co/black-forest-labs/FLUX.1-dev
```

Flux needs additional CLIP and VAE models — see [Models Guide](models-guide.md#flux).

---

## Fine-Tuned Models (Checkpoints)

Beyond the base models, the community has created thousands of **fine-tuned checkpoints** that specialize in specific styles. These are full model files that replace the base checkpoint:

| Style | Example Models |
|-------|---------------|
| Photorealistic | RealisticVision, epiCRealism, Juggernaut XL |
| Anime/Manga | AbyssOrangeMix, CounterfeitXL, Pony Diffusion |
| Digital Art | DreamShaper, Dreamlike Photoreal |
| 3D/CG | Protogen, RevAnimated |

Download from [CivitAI](https://civitai.com/models) → filter by checkpoint type → download `.safetensors` files.

```bash
# Place all checkpoints here:
/mnt/disks/models/models/checkpoints/
```

After adding a model, click the **refresh** icon on the Load Checkpoint node in ComfyUI (or restart ComfyUI) to see it in the dropdown.

---

## LoRA — Style Add-ons (Small Files)

LoRA files are small (~10–150 MB) adapters that modify a base model's style without replacing it. You stack them on top of any checkpoint.

```bash
# Place LoRA files here:
/mnt/disks/models/models/loras/

# In ComfyUI, add a "Load LoRA" node between Load Checkpoint and KSampler
# Set strength (0.5–1.0 is typical)
```

Popular LoRA sources: CivitAI, Hugging Face

---

## VAE — Image Quality Fix

The VAE (Variational Autoencoder) converts between compressed latent space and actual images. A better VAE = sharper, more saturated images.

```bash
# Most SD 1.5 models need:
cd /mnt/disks/models/models/vae
wget "https://huggingface.co/stabilityai/sd-vae-ft-mse-original/resolve/main/vae-ft-mse-840000-ema-pruned.safetensors"

# In ComfyUI: add "Load VAE" node → connect to VAE Decode node
```

SD 1.5 checkpoints sometimes have a baked-in VAE that causes washed-out colors — always use an external VAE for best results.
