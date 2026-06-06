# gcp-ai-studio

A self-hosted GCP stack for ComfyUI, llama.cpp, and Open WebUI on a single GPU VM. Built on top of [ComfyUI](https://github.com/comfyanonymous/ComfyUI), [llama.cpp](https://github.com/ggml-org/llama.cpp), and Terraform.

## What is this?

ComfyUI is a **node-based GUI** for running AI image and video generation models locally. Think of it as a visual programming tool where you connect blocks (nodes) to build generation pipelines — no coding required.

This project provisions a dedicated GCP VM with an NVIDIA A100 GPU, isolated VPC, and persistent storage, then installs the enabled services on first boot.

**Supports:**
- Text-to-image (Stable Diffusion 1.5, SDXL, Flux, SD3)
- Image-to-image (img2img, style transfer)
- **Image-to-video** (Wan2.1, SVD, AnimateDiff, CogVideoX)
- Upscaling, inpainting, ControlNet, LoRA
- Local LLM inference via llama.cpp
- Browser chat UI with Open WebUI

---

## What Changed

- The repository name is now `gcp-ai-studio`.
- The current default deployment targets an A100 VM and includes optional `ComfyUI`, `llama.cpp`, and `Open WebUI` services.
- The repo layout is intentionally unchanged. The current structure is already small and clear, while changing Terraform paths or backend layout would create unnecessary state-migration risk.
- The existing Terraform backend prefix can stay as-is for continuity, even though the repository name changed.

---

## Infrastructure

| Resource | Details |
|----------|---------|
| VM | `a2-highgpu-1g` |
| GPU | NVIDIA A100 — 40 GB VRAM |
| Boot disk | 100 GB `pd-balanced` — Deep Learning VM (CUDA pre-installed) |
| Data disk | 200 GB `pd-balanced` — models, outputs, inputs |
| Network | Isolated VPC `comfyui-vpc` (10.1.0.0/24) |
| Access | IAP TCP tunnel — no public IP |
| Buckets | `*-comfyui-models` / `*-comfyui-outputs` |
| Services | ComfyUI `8188`, llama.cpp `8080`, Open WebUI `3000` |

---

## Quick Start

### 1. Deploy infrastructure
```bash
cp .env.example .env
# edit .env

make init
make apply
# First boot takes time to install enabled services and download models
```

### 2. Access services
```bash
# ComfyUI
make tunnel

# llama.cpp OpenAI-compatible API
make llm-tunnel

# Open WebUI
make webui-tunnel

# Then open:
# http://localhost:8188
# http://localhost:3000
```

### 3. Choose which services are enabled

The default is to enable all three services. You can override them in `.env`:

```env
ENABLE_COMFYUI=true
ENABLE_LLAMA=true
ENABLE_OPEN_WEBUI=true
```

`ENABLE_OPEN_WEBUI=true` requires `ENABLE_LLAMA=true`.

### 4. Add models (image-to-video)
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

### 5. Stop VM when done (save costs)
```bash
make stop
# Restart anytime with: make start
```

---

## Docs

| Guide | Description |
|-------|-------------|
| [Getting Started](docs/getting-started.md) | First-time setup, UI walkthrough, first generation |
| [LLM Guide](docs/llm-guide.md) | llama.cpp, Qwen3.6-35B-A3B, Open WebUI access |
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
make llm-tunnel Forward localhost:8080 to llama.cpp via IAP
make webui-tunnel Forward localhost:3000 to Open WebUI via IAP
make status    VM state + ComfyUI service health
make logs      Stream ComfyUI logs
make gpu       Show GPU utilization (nvidia-smi)
```

---

## Repo Layout

```text
.
├── .env.example
├── Makefile
├── README.md
├── docs/
├── llm/
└── terraform/
```

- `docs/` holds operator-facing guides.
- `terraform/` owns infrastructure, startup automation, and service toggles.
- `llm/` contains local smoke tests for the llama.cpp API.

No structural change is needed right now. The main problem was naming and documentation drift, not package layout.

---

## Cost Estimate

### VM Cost (only when running)

| Component | Price |
|-----------|-------|
| a2-highgpu-1g (A100 40 GB) | Higher than L4/T4 configurations |
| **VM total (running)** | Check current GCP pricing for your region |

Use `make stop` aggressively when not working. The A100 profile is optimized for larger image-to-video and LLM workloads, not lowest cost.

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
| L4 (g2-standard-8) | 24 GB | ~$1.20/hr | Lower-cost ComfyUI-only setups |
| **A100 (a2-highgpu-1g) ← current** | **40 GB** | Check current pricing | **ComfyUI + llama.cpp + Open WebUI on one VM** |

Change GPU in [terraform.tfvars](terraform/terraform.tfvars) → `compute_config.machine_type` + `compute_config.gpu.type`
