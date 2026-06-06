# Getting Started with ComfyUI

## What is ComfyUI?

ComfyUI is a **node-based visual interface** for running AI generation models. Instead of a simple prompt box, it gives you a canvas of connected blocks (called **nodes**) where each node does one thing — load a model, encode text, generate an image, upscale, convert to video, etc.

```
[Load Model] → [CLIP Text Encode] → [KSampler] → [VAE Decode] → [Save Image]
```

This makes it extremely flexible — you can build complex multi-step pipelines, chain models together, and exactly control every parameter.

---

## Step 1 — Deploy and Start the VM

```bash
# From ~/gcp-ai-studio/
cp .env.example .env
# edit .env if needed

make init
make apply
```

First boot takes time while the enabled services install. You can watch progress:

```bash
make ssh
# Once inside:
sudo tail -f /var/log/comfyui-init.log
```

When you see the relevant initialization messages in `/var/log/comfyui-init.log`, the selected services are ready.

## Service Toggles

All services are enabled by default in `.env`:

```env
ENABLE_COMFYUI=true
ENABLE_LLAMA=true
ENABLE_OPEN_WEBUI=true
```

If you only want the ComfyUI UI, you can disable the others before `make apply`.

---

## Step 2 — Open ComfyUI in Your Browser

ComfyUI runs on the VM with no public IP. You access it through an IAP tunnel:

```bash
# In a terminal on your LOCAL machine:
make tunnel
```

You'll see:
```
Opening IAP tunnel: localhost:8188 → comfyui-vm:8188
Listening on port [8188]...
```

Now open **http://localhost:8188** in your browser. Keep the terminal open — closing it closes the tunnel.

If `ENABLE_LLAMA=true` and `ENABLE_OPEN_WEBUI=true`, you can also use:

```bash
make llm-tunnel
make webui-tunnel
```

Open WebUI will be available at **http://localhost:3000**.

---

## Step 3 — The ComfyUI Interface

When you first open ComfyUI, you'll see a default workflow canvas:

```
┌─────────────────────────────────────────────────────────────┐
│  [Load Checkpoint]                                          │
│       ↓ MODEL                                               │
│  [CLIP Text Encode "positive"]  [CLIP Text Encode "neg"]   │
│       ↓ CONDITIONING              ↓ CONDITIONING            │
│  [Empty Latent Image]                                       │
│       ↓ LATENT                                              │
│  [KSampler] ← MODEL + CONDITIONING + CONDITIONING          │
│       ↓ LATENT                                              │
│  [VAE Decode]                                               │
│       ↓ IMAGE                                               │
│  [Save Image]                                               │
└─────────────────────────────────────────────────────────────┘
```

### Key UI Elements

| Element | What it does |
|---------|-------------|
| **Canvas** | Drag to pan, scroll to zoom, double-click empty space to add nodes |
| **Queue Prompt** (bottom right) | Run the current workflow |
| **Load** | Load a saved workflow (.json file) |
| **Save** | Save your current workflow |
| **Manager** | Opens ComfyUI-Manager — install new custom nodes |
| Right-click canvas | Add Node menu |
| Right-click a node | Options (bypass, mute, delete, etc.) |

### Node Anatomy

Each node has:
- **Inputs** (left side, colored dots) — connect from another node's output
- **Outputs** (right side, colored dots) — connect to another node's input
- **Widgets** — sliders, dropdowns, text fields (inline parameters)

Colors indicate data types:
- 🟡 **Yellow** — MODEL
- 🟣 **Purple** — CONDITIONING (text prompts)
- 🔵 **Blue** — LATENT (compressed image data)
- 🔴 **Red** — IMAGE
- 🟠 **Orange** — VAE

---

## Step 4 — Your First Image Generation

Before generating, you need at least one checkpoint model. See the [Models Guide](models-guide.md) for how to download one.

Assuming you have `v1-5-pruned-emaonly.safetensors` in `/mnt/disks/models/models/checkpoints/`:

1. Click **Load Checkpoint** node → select your model from the dropdown
2. Click the positive **CLIP Text Encode** node → type your prompt, e.g.:
   ```
   a beautiful mountain landscape, golden hour, photorealistic, 8k
   ```
3. Click the negative **CLIP Text Encode** node → type what to avoid:
   ```
   blurry, bad quality, watermark, text, ugly
   ```
4. In **Empty Latent Image** → set width/height (512×512 for SD1.5, 1024×1024 for SDXL)
5. In **KSampler** → set:
   - `steps`: 20 (more = better quality, slower)
   - `cfg`: 7 (higher = follows prompt more strictly)
   - `sampler_name`: `euler_ancestral` (good default)
   - `scheduler`: `karras`
6. Click **Queue Prompt** → watch the progress bar

Your image appears in the **Save Image** node and is saved to `/mnt/disks/models/output/`.

---

## Step 5 — Stop When Done

The current default setup uses an A100 VM, so idle cost is materially higher than older T4/L4 examples. Stop it when you're done:

```bash
make stop
```

Your data disk (models, outputs) persists. Restart anytime:

```bash
make start
# Wait ~1 minute for boot, then:
make tunnel
```

---

## Loading Pre-built Workflows

Instead of building from scratch, you can load ready-made workflows:

1. Download a workflow `.json` file (from [Civitai](https://civitai.com/), community repos, or the `docs/` folder in this project)
2. In ComfyUI: click **Load** → select the `.json` file
3. The full node graph loads — just swap in your models and run

For image-to-video workflows, see [Image-to-Video Workflow](image-to-video.md).

---

## Checking ComfyUI Logs

If something isn't working:

```bash
# Real-time logs
make logs

# Or SSH in and check directly
make ssh
sudo journalctl -u comfyui -n 100 --no-pager
```

Common startup errors and fixes are in [Tips & Tricks](tips-and-tricks.md).
