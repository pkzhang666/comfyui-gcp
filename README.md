# ComfyUI Workflow — Image to Video

A self-hosted ComfyUI environment on GCP with GPU, designed for image-to-video AI generation workflows. Built on top of [ComfyUI](https://github.com/comfyanonymous/ComfyUI) and deployed via Terraform on the `$PROJECT_ID` project.

## What is this?

ComfyUI is a **node-based GUI** for running AI image and video generation models locally. Think of it as a visual programming tool where you connect blocks (nodes) to build generation pipelines — no coding required.

This project provisions a dedicated GCP VM with an NVIDIA T4 GPU, isolated VPC, and persistent storage, then auto-installs ComfyUI on first boot.

**Supports:**
- Text-to-image (Stable Diffusion 1.5, SDXL, Flux, SD3)
- Image-to-image (img2img, style transfer)
- **Image-to-video** (Wan2.1, SVD, AnimateDiff, CogVideoX)
- Upscaling, inpainting, ControlNet, LoRA

---

## Infrastructure

| Resource | Details |
|----------|---------|
| VM | `g2-standard-8` (8 vCPU, 32 GB RAM) |
| GPU | NVIDIA L4 — 24 GB VRAM |
| Boot disk | 100 GB SSD — Deep Learning VM (CUDA pre-installed) |
| Data disk | 500 GB SSD — models, outputs, inputs |
| Network | Isolated VPC `comfyui-vpc` (10.1.0.0/24) |
| Access | IAP TCP tunnel — no public IP |
| Buckets | `*-comfyui-models` / `*-comfyui-outputs` |

---

## Quick Start

### 1. Deploy infrastructure
```bash
make init
make apply
# First boot takes ~10 minutes to install ComfyUI
```

### 2. Access ComfyUI
```bash
# Terminal 1 — open IAP tunnel
make tunnel

# Then open in browser:
# http://localhost:8188
```

### 3. Add models (image-to-video)
```bash
# SSH into VM
make ssh

# Download Wan2.1 (recommended for image-to-video)
cd /mnt/disks/models/models/unet
wget "https://huggingface.co/Wan-AI/Wan2.1-I2V-14B-480P/resolve/main/..."

# Or copy from GCS
gsutil -m cp gs://$MODELS_BUCKET/checkpoints/your-model.safetensors \
  /mnt/disks/models/models/checkpoints/
```

### 4. Stop VM when done (save costs)
```bash
make stop
# Restart anytime with: make start
```

---

## Docs

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | First-time setup, UI walkthrough, first generation |
| [Stable Diffusion Guide](docs/stable-diffusion.md) | What SD is, versions, which to use |
| [Models Guide](docs/models-guide.md) | How to download, install, and manage models |
| [Image-to-Video Workflow](docs/image-to-video.md) | Step-by-step Wan2.1 / SVD workflows |
| [Tips & Tricks](docs/tips-and-tricks.md) | Performance tuning, common errors, best practices |

---

## Make Targets

```
make check     Check gcloud + terraform prerequisites
make init      Initialize Terraform
make plan      Preview changes
make apply     Deploy / update infrastructure
make destroy   Tear down everything

make start     Start the VM
make stop      Stop the VM (save costs ~$0.75/hr with T4)
make ssh       SSH into VM via IAP
make tunnel    Forward localhost:8188 to ComfyUI via IAP
make status    VM state + ComfyUI service health
make logs      Stream ComfyUI logs
make gpu       Show GPU utilization (nvidia-smi)
```

---

## Cost Estimate (us-central1, as of 2025)

### VM Cost (only when running)

| Component | Price |
|-----------|-------|
| g2-standard-8 (8 vCPU, 32 GB RAM + L4 GPU) | ~$1.20 / hr |
| **VM total (running)** | **~$1.20 / hr** |

> L4 GPU pricing is bundled into the g2 machine type — no separate GPU charge.

### Storage Cost (always-on, even when VM is stopped)

| Component | Price |
|-----------|-------|
| 200 GB pd-balanced data disk | $0.048 / GB / month = **$9.60 / month** |
| 100 GB pd-balanced boot disk | $0.048 / GB / month = **$4.80 / month** |
| GCS Standard (models bucket) | $0.020 / GB / month |
| GCS Standard (outputs bucket) | $0.020 / GB / month |

> Switched to `pd-balanced` (HDD) — 3.5× cheaper than `pd-ssd`, still fast enough for model loading.

### Real-World Examples (L4 config)

| Usage Pattern | Estimated Monthly Cost |
|---------------|----------------------|
| 2 hrs/day, 20 days/month | ~$48 VM + ~$15 disk = **~$63/month** |
| 4 hrs/day, 10 days/month | ~$48 VM + ~$15 disk = **~$63/month** |
| Storage only (VM stopped all month) | **~$15/month** (disks only) |
| Light testing (1 hr/week) | ~$5 VM + ~$15 disk = **~$20/month** |

### Cost-Saving Tips

```bash
# Stop VM when not in use — eliminates $0.73/hr charge
make stop

# Resume in ~1 minute
make start
```

- **Biggest cost is the 500 GB SSD disk** — it runs 24/7 even when VM is off
- If you stop testing for a long period, consider using `make destroy` to delete everything (including the disk)
- Models stored in GCS cost 8× less than on pd-ssd — archive unused models there
- Downgrade data disk to `pd-balanced` (HDD, $0.048/GB/month) to reduce disk cost to ~$24/month at the cost of slower model loading

### GPU Options

| GPU | VRAM | VM + GPU / hr | Best For |
|-----|------|---------------|---------|
| T4 (n1-standard-8) | 16 GB | ~$0.73/hr | Budget testing, 480P |
| **L4 (g2-standard-8) ← current** | **24 GB** | **~$1.20/hr** | **Wan2.1 720P, recommended** |
| A100 (a2-highgpu-1g) | 40 GB | ~$3.67/hr | Fastest, largest models |

Change GPU in [terraform.tfvars](terraform/terraform.tfvars) → `compute_config.machine_type` + `compute_config.gpu.type`
