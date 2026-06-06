# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Infrastructure-as-code for a self-hosted ComfyUI environment on GCP — a GPU-backed VM running AI image/video generation. The entire stack is managed by Terraform; there is no application code to build or test locally.

## Prerequisites

```bash
make check   # validates gcloud + terraform CLIs and active gcloud auth
```

## Infrastructure Commands

```bash
# One-time setup (copy example files first — see Configuration below)
make init    # terraform init with GCS backend

# Deploy/update
make plan    # preview changes
make apply   # deploy or update infrastructure

# Daily use
make start   # start the VM (billing resumes ~$1.20/hr)
make stop    # stop the VM (eliminates per-hour charge; disk costs persist)
make tunnel  # IAP tunnel → http://localhost:8188 (ComfyUI UI)
make ssh     # SSH into VM via IAP
make status  # VM state + ComfyUI systemd service health
make logs    # stream ComfyUI service logs (journalctl -u comfyui -f)
make gpu     # nvidia-smi on the VM

# Teardown
make destroy # destroys everything including the data disk
make clean   # remove local .terraform cache
```

## Configuration

Two gitignored files must exist before `make init`:

| File | Source |
|------|--------|
| `terraform/backend.tfvars` | Copy `backend.tfvars.example` — GCS bucket + prefix for Terraform state |
| `terraform/terraform.tfvars` | Copy `terraform.tfvars.example` — project ID, zone, machine type, bucket names |

Key settings to customize in `terraform.tfvars`:
- `compute_config.machine_type` + `compute_config.gpu.type` — choose T4/L4/A100
- `storage_config.models_bucket.name` / `outputs_bucket.name` — must be globally unique GCS bucket names
- `compute_config.data_disk.size_gb` — 200 GB default; models alone can be 50–100 GB each
- `compute_config.preemptible = true` — saves ~70% on VM cost but GCP may reclaim with 30s notice

## Architecture

### Terraform Module Structure

```
terraform/
├── main.tf            # root: wires 4 modules together with dependencies
├── variables.tf       # all input variables with typed objects and defaults
├── outputs.tf         # post-deploy instructions, tunnel/ssh commands
└── modules/
    ├── networking/    # VPC, subnet, Cloud Router, Cloud NAT, firewall rules
    ├── iam/           # service account + IAM bindings (storage, logging, monitoring)
    ├── storage/       # 2 GCS buckets: *-comfyui-models and *-comfyui-outputs
    └── compute/       # VM instance, persistent data disk, startup script
```

Module dependency order: `apis` → `networking` + `iam` → `storage` → `compute`

### VM Networking (no public IP)

The VM has no external IP. All access goes through **IAP TCP tunneling**:
- `make tunnel` → port-forwards `localhost:8188` to the VM's ComfyUI port
- `make ssh` → SSH over IAP (no bastion, no VPN needed)
- Cloud NAT provides outbound internet for package installs and `git clone`

### First-Boot Startup Script

`terraform/modules/compute/startup-script.sh.tpl` is rendered by Terraform and embedded as a VM metadata startup script. It runs on **every boot** but is idempotent — subsequent boots detect `/etc/comfyui-initialized` and only restart the service.

First-boot sequence (~10 min total):
1. Wait for NVIDIA drivers (Deep Learning VM installs them on first boot)
2. Mount/format the 200 GB persistent data disk at `/mnt/disks/models`
3. Clone ComfyUI to `/opt/comfyui`, create venv, install PyTorch CUDA 12.1
4. Install ComfyUI-Manager and VideoHelperSuite custom nodes
5. Create model subdirectory tree on the data disk; symlink `/opt/comfyui/{models,output,input}` → data disk
6. Register and start `comfyui.service` (systemd)

### Disk Layout

| Path | Disk | Purpose |
|------|------|---------|
| `/opt/comfyui` | 100 GB boot (pd-balanced) | ComfyUI code, venv, custom nodes |
| `/mnt/disks/models/models/` | 200 GB data (pd-balanced) | All model files (checkpoints, VAE, LoRA, unet, etc.) |
| `/mnt/disks/models/output/` | same data disk | Generated images/videos |
| `/mnt/disks/models/input/` | same data disk | Input images |

The data disk persists across VM stop/start and Terraform updates; it is only destroyed by `make destroy`.

### Model Management

Models are placed directly on the data disk via SSH:
```bash
make ssh
# then on VM:
cd /mnt/disks/models/models/<subdir>   # checkpoints, unet, loras, vae, etc.
wget <huggingface-url>
# or pull from GCS:
gsutil -m cp gs://<models-bucket>/... .
```

The `*-comfyui-models` GCS bucket serves as cheaper long-term model storage; the VM's data disk is the working copy.
