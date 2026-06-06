# LLM Guide — Qwen3.6-35B-A3B on A100 via llama.cpp

This guide explains how the LLM service is deployed alongside ComfyUI on the same A100 VM, and how to use it.

---

## Overview

| Component | Details |
|-----------|---------|
| Model | [HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive](https://huggingface.co/HauhauCS/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive) |
| Format | GGUF (default: `Q6_K_P` — 30.6 GB) |
| Runtime | [llama.cpp](https://github.com/ggml-org/llama.cpp) built from source with CUDA (SM 80 / A100) |
| API | OpenAI-compatible at `http://localhost:8080/v1` (via IAP tunnel) |
| VM | Same A100 (`a2-highgpu-1g`, 40 GB VRAM) as ComfyUI |

---

## Quantisation Options for A100 40 GB

| Quant | Size | Notes |
|-------|------|-------|
| `Q6_K_P` | 30.6 GB | **Default — best quality, fits with headroom** |
| `Q4_K_M` | 21.2 GB | Faster, more KV-cache headroom for longer contexts |
| `Q4_K_P` | 23.4 GB | Balanced quality/speed |
| `Q5_K_P` | 28.0 GB | Near-Q6 quality |
| `Q8_K_P` | 43.6 GB | Too large for 40 GB VRAM — do not use |

To change the quant, edit `llm_config.model_quant` in `terraform/terraform.tfvars` (or `.env`) and re-run `make apply`.

---

## First-time Setup

The LLM service is deployed automatically alongside ComfyUI via the same Terraform apply when `ENABLE_LLAMA=true`.

```bash
# 1. Fill in your .env (copy from example if you haven't yet)
cp .env.example .env
# edit .env → set PROJECT_ID, STATE_BUCKET, etc.

# Optional service toggles
# ENABLE_COMFYUI=true
# ENABLE_LLAMA=true
# ENABLE_OPEN_WEBUI=true

# 2. Deploy (or re-deploy if already running)
make apply
```

On first boot the startup script will:
1. Wait for NVIDIA drivers and mount the data disk
2. Install and configure ComfyUI (marks `/etc/comfyui-initialized`)
3. Clone and build llama.cpp with CUDA (`-DCMAKE_CUDA_ARCHITECTURES=80`)
4. Download the GGUF model (~30 GB) and mmproj vision projector (~900 MB)  
   from HuggingFace to `/mnt/disks/models/llm/`
5. Create and start the `llama-server` systemd service (marks `/etc/llama-initialized`)

> **Note:** The model download takes ~5–10 min on a GCP VM (internal bandwidth).  
> Check progress with `make llm-logs`.

---

## Connecting to the API

The VM has no public IP. Access is via IAP tunnel only.

If you also enable `ENABLE_OPEN_WEBUI=true`, the browser chat UI is exposed separately on port `3000` and uses the llama.cpp API on `8080`.

**Step 1 — Open the tunnel** (keep this terminal open):
```bash
make llm-tunnel
# Tunnel: localhost:8080 → VM:8080
```

**Step 2 — Test the API** (in a new terminal):
```bash
make llm-test
# or directly:
./llm/api-test.sh
```

**Step 3 — Use with any OpenAI-compatible client:**
```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8080/v1", api_key="not-required")

response = client.chat.completions.create(
    model="qwen3",
    messages=[{"role": "user", "content": "Hello, who are you?"}],
    max_tokens=512,
)
print(response.choices[0].message.content)
```

```bash
# curl example
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3",
    "messages": [{"role": "user", "content": "Explain CUDA in one paragraph."}],
    "max_tokens": 256
  }'
```

---

## Qwen3 Thinking Mode

Qwen3 supports a `/think` chain-of-thought mode. To enable it, prepend `/think` to your message or use the `thinking` system prompt:

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3",
    "messages": [
      {"role": "user", "content": "/think\nSolve: if 2x + 3 = 11, what is x?"}
    ],
    "max_tokens": 1024
  }'
```

---

## Operations

```bash
make llm-status    # Show service state + model files on disk
make llm-logs      # Stream llama-server logs (Ctrl+C to stop)
make llm-tunnel    # Open IAP port-forward (required to reach API)
make llm-test      # Quick API health check (needs llm-tunnel open)
```

Check GPU usage (both ComfyUI and llama-server share the A100):
```bash
make gpu
```

---

## Configuration

`llm_config` in `terraform/terraform.tfvars`:

```hcl
llm_config = {
  port         = 8080        # llama-server listen port
  model_quant  = "Q6_K_P"   # GGUF quantisation (see table above)
  context_size = 32768       # Context window in tokens (total across all --parallel slots)
}
```

Service enablement is controlled separately in `.env` through `ENABLE_LLAMA` and `ENABLE_OPEN_WEBUI`.

After changing any value, run `make apply` to regenerate the startup script and trigger re-init on the next VM restart.

---

## Troubleshooting

**Service not started after `make apply`**  
The model download takes time. Check `make llm-logs` — you'll see download progress. The service starts only after the download completes.

**`/etc/llama-initialized` exists but service is broken**  
SSH in and reset:
```bash
make ssh
# On the VM:
sudo rm /etc/llama-initialized
sudo systemctl restart llama-server
sudo journalctl -u llama-server -f
```

**Out of VRAM error**  
Switch to a smaller quant (`Q4_K_M`) in `terraform.tfvars` and reset as above. ComfyUI should be stopped first:
```bash
make ssh
# On the VM:
sudo systemctl stop comfyui
sudo systemctl restart llama-server
```

**Build failed (`cmake` error)**  
Check `/var/log/llama-build.log` on the VM via SSH.
