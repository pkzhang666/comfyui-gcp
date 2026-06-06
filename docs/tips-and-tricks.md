# Tips & Tricks — Performance, Errors, and Best Practices

## Memory Management on T4 (16 GB VRAM)

### Check VRAM Usage

```bash
make gpu
# Or while generating:
make ssh
watch -n 1 nvidia-smi
```

### Out of Memory (OOM) Errors

If you get `CUDA out of memory` or the generation crashes:

1. **Use tiled VAE decoding** — swap `VAE Decode` for `VAE Decode Tiled` in your workflow. Cuts VRAM for decoding by ~50%

2. **Reduce batch size** — in Empty Latent Image, set `batch_size` to 1

3. **Lower resolution** — for SDXL use 896×512 instead of 1024×1024

4. **Enable fp16/bf16** — in KSampler, some models support half precision

5. **Free VRAM between generations** — in ComfyUI Settings (gear icon) → enable **Free Memory After Each Generation**

6. **Use xformers** (already included in Deep Learning VM PyTorch):
   ```bash
   # Verify xformers is available
   make ssh
   source /opt/comfyui/venv/bin/activate
   python -c "import xformers; print(xformers.__version__)"
   ```

---

## Speed Optimization

### Faster Sampling

| Change | Speed Gain | Quality Loss |
|--------|-----------|--------------|
| Steps 30 → 20 | ~33% faster | Minimal |
| Steps 20 → 10 | ~50% faster | Noticeable |
| Use DPM++ 2M Karras sampler | ~20% faster | Minimal vs Euler A |
| LCM/Lightning LoRA (4 steps) | ~75% faster | Some quality loss |

### Caching Models

Once a model is loaded into VRAM, subsequent generations are much faster. Don't change the checkpoint between generations if possible.

In ComfyUI Settings → **Enable Model Caching** (keeps model in VRAM between generations).

---

## Common Errors and Fixes

### "Error loading model: No module named torch"

ComfyUI service started before PyTorch was ready. Restart:
```bash
make ssh
sudo systemctl restart comfyui
# Wait 30 seconds
make tunnel
```

### "Model file not found" in dropdown

The file exists but ComfyUI hasn't scanned it yet:
```bash
# Option 1 — click the refresh icon on the Load Checkpoint node
# Option 2 — restart ComfyUI
make ssh
sudo systemctl restart comfyui
```

### "Connection refused" on localhost:8188

The IAP tunnel isn't open. Run in a separate terminal:
```bash
make tunnel
```
If the tunnel is open but still refused, ComfyUI may not be running:
```bash
make ssh
sudo systemctl status comfyui
sudo systemctl start comfyui
```

### Video generation produces a black screen

- Wrong VAE selected — make sure the VAE matches the model family
- `augmentation_level` too high for SVD — keep at 0.0–0.05
- Input image resolution mismatch — resize to model's expected dimensions

### "RuntimeError: CUDA error: device-side assert triggered"

Usually a mismatch between model type and workflow nodes. Common cause: using an SD 1.5 workflow with an SDXL checkpoint (or vice versa). Load the correct workflow for your model.

### First boot: ComfyUI not starting after 15 minutes

Check the init log:
```bash
make ssh
sudo cat /var/log/comfyui-init.log | tail -50
```

If stuck on NVIDIA driver installation, the Deep Learning VM may need a reboot:
```bash
sudo reboot
# Wait 2 minutes, then reconnect
```

---

## Workflow Tips

### Save Every Working Workflow

ComfyUI's **Save** button exports the current graph as a `.json` file. Do this every time you get a good result — the workflow encodes all settings including model names, sampler params, and node connections.

```bash
# Download your saved workflows to local machine
gcloud compute scp "comfyui-vm:/opt/comfyui/workflows/*.json" ./saved-workflows/ \
  --zone=us-central1-a --project=$PROJECT_ID --tunnel-through-iap
```

### Use Workflow Templates from Examples

The ComfyUI repo includes example workflows for every model type:
- In ComfyUI → Load → navigate to `/opt/comfyui/comfyui_examples/`
- Or download from: https://github.com/comfyanonymous/ComfyUI_examples

### Seed Control for Reproducibility

In KSampler, set a fixed `seed` value instead of `-1` (random). This lets you reproduce the same output or make controlled variations.

### Batch Generation (Multiple Images)

In **Empty Latent Image**, increase `batch_size` to 2–4. Generates multiple images in parallel. Note: uses proportionally more VRAM.

---

## Cost Saving Tips

### Always Stop the VM When Done

```bash
make stop
# Restart when needed:
make start
```

T4 GPU costs ~$0.73/hr. Leaving it on overnight = ~$5.80 wasted.

### Use a Startup Script to Auto-Stop

SSH into VM and set a cron job:
```bash
# Auto-stop after 2 hours of inactivity
# (checks if any generation is running)
echo "0 */2 * * * root systemctl is-active --quiet comfyui && nvidia-smi | grep -q 'No running processes' && /sbin/shutdown -h now" | sudo tee /etc/cron.d/auto-stop
```

### Store Models in GCS, Not Disk

For models you don't use often, keep them in GCS (much cheaper than pd-ssd) and only pull to disk when needed:

```bash
# Archive to GCS
gsutil mv /mnt/disks/models/models/checkpoints/unused-model.safetensors \
  gs://$MODELS_BUCKET/archive/

# Pull back when needed
gsutil cp gs://$MODELS_BUCKET/archive/unused-model.safetensors \
  /mnt/disks/models/models/checkpoints/
```

---

## Quality Tips

### Prompt Engineering

**Good prompt structure:**
```
[Subject], [Style/Medium], [Lighting], [Camera], [Quality tags]

Example:
a portrait of a woman with flowing red hair, oil painting style, 
soft diffused lighting, close-up shot, masterpiece, highly detailed, 8k
```

**Negative prompts to always include:**
```
blurry, bad anatomy, extra limbs, watermark, text, logo, 
low quality, jpeg artifacts, grainy, overexposed, underexposed
```

### CFG Scale Guide

| CFG Value | Behavior |
|-----------|----------|
| 1–3 | Very creative, ignores prompt (good for SVD) |
| 4–6 | Balanced, some creativity |
| 7–9 | Follows prompt closely (good default) |
| 10–15 | Very literal, can oversaturate |
| 16+ | Usually looks bad (burned colors) |

### Denoising Strength for img2img

When using image-to-image (not video):
- `0.3–0.5` — subtle changes, preserves source image
- `0.6–0.75` — moderate changes, good for style transfer
- `0.8–1.0` — major changes, almost ignores source image
