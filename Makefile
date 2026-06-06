TERRAFORM_DIR := terraform

# Load .env if present (copy .env.example → .env and fill in your values)
-include .env
export

.PHONY: help check init plan apply destroy start stop ssh tunnel status logs gpu-status clean genconfig llm-tunnel llm-logs llm-status llm-test webui-tunnel webui-logs

help:
	@echo ""
	@echo "ComfyUI + LLM — Infrastructure Management"
	@echo "==========================================="
	@echo ""
	@echo "  check      Check prerequisites (gcloud, terraform)"
	@echo "  genconfig  Generate terraform/*.tfvars from .env + templates"
	@echo "  init       Initialize Terraform backend"
	@echo "  plan       Preview infrastructure changes"
	@echo "  apply      Deploy/update infrastructure"
	@echo "  destroy    Tear down all infrastructure"
	@echo ""
	@echo "  start    Start the VM (billing resumes)"
	@echo "  stop     Stop the VM to save costs"
	@echo "  ssh      Open SSH session via IAP tunnel"
	@echo "  tunnel   Forward ComfyUI port 8188 → localhost:8188"
	@echo "  status   Show VM state and service status"
	@echo "  logs     Stream ComfyUI service logs"
	@echo "  gpu      Show GPU utilization (nvidia-smi)"
	@echo ""
	@echo "  llm-tunnel  Forward llama-server port $(LLAMA_PORT) → localhost:$(LLAMA_PORT)"
	@echo "  llm-logs    Stream llama-server logs"
	@echo "  llm-status  Show llama-server service status"
	@echo "  llm-test    Run API test (requires llm-tunnel open in another terminal)"
	@echo ""
	@echo "  webui-tunnel  Forward Open WebUI port $(WEBUI_PORT) → localhost:$(WEBUI_PORT)"
	@echo "  webui-logs    Stream Open WebUI container logs"
	@echo ""
	@echo "  clean    Remove local .terraform cache"
	@echo ""

check:
	@echo "Checking prerequisites..."
	@which terraform > /dev/null 2>&1 || (echo "ERROR: terraform not found — install from https://developer.hashicorp.com/terraform"; exit 1)
	@which gcloud > /dev/null 2>&1 || (echo "ERROR: gcloud not found — install Google Cloud SDK"; exit 1)
	@which envsubst > /dev/null 2>&1 || (echo "ERROR: envsubst not found — install gettext (brew install gettext / apt install gettext)"; exit 1)
	@gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | grep -q . || \
		(echo "ERROR: No active gcloud account — run: gcloud auth login"; exit 1)
	@test -n "$(PROJECT_ID)" || (echo "ERROR: PROJECT_ID not set — copy .env.example → .env and fill in values"; exit 1)
	@echo "  project : $(PROJECT_ID)"
	@echo "  region  : $(REGION)"
	@echo "  zone    : $(ZONE)"
	@echo "  vm      : $(VM_NAME)"
	@echo "All checks passed."

# Generate terraform/backend.tfvars and terraform/terraform.tfvars from templates + .env
genconfig: check
	@test -f .env || (echo "ERROR: .env not found — copy .env.example → .env and fill in values"; exit 1)
	envsubst < $(TERRAFORM_DIR)/backend.tfvars.tpl > $(TERRAFORM_DIR)/backend.tfvars
	envsubst < $(TERRAFORM_DIR)/terraform.tfvars.tpl > $(TERRAFORM_DIR)/terraform.tfvars
	@echo "Generated $(TERRAFORM_DIR)/backend.tfvars and $(TERRAFORM_DIR)/terraform.tfvars from .env"

init: genconfig
	cd $(TERRAFORM_DIR) && terraform init -backend-config=backend.tfvars

plan: init
	cd $(TERRAFORM_DIR) && terraform plan -var-file=terraform.tfvars

apply: init
	cd $(TERRAFORM_DIR) && terraform apply -var-file=terraform.tfvars

destroy:
	@echo "WARNING: This will destroy all ComfyUI infrastructure including the data disk."
	@read -p "Type 'yes' to confirm: " confirm && [ "$$confirm" = "yes" ] || exit 1
	cd $(TERRAFORM_DIR) && terraform destroy

start:
	gcloud compute instances start $(VM_NAME) --zone=$(ZONE) --project=$(PROJECT_ID)
	@echo "VM starting. Use 'make status' to check."

stop:
	gcloud compute instances stop $(VM_NAME) --zone=$(ZONE) --project=$(PROJECT_ID)
	@echo "VM stopped. Use 'make start' to restart."

ssh:
	gcloud compute ssh $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--tunnel-through-iap

tunnel:
	@echo "Opening IAP tunnel: localhost:8188 → $(VM_NAME):8188"
	@echo "Open http://localhost:8188 in your browser after the tunnel connects."
	gcloud compute start-iap-tunnel $(VM_NAME) 8188 \
		--local-host-port=localhost:8188 \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID)

status:
	@echo "=== VM ==="
	gcloud compute instances describe $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--format="table(name,status,machineType.basename(),zone.basename())" 2>/dev/null || \
		echo "VM not found — run 'make apply' first"
	@echo ""
	@echo "=== ComfyUI Service ==="
	gcloud compute ssh $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--tunnel-through-iap \
		--command="systemctl status comfyui --no-pager -l" 2>/dev/null || true

logs:
	gcloud compute ssh $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--tunnel-through-iap \
		--command="sudo journalctl -u comfyui -f --no-pager"

gpu:
	gcloud compute ssh $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--tunnel-through-iap \
		--command="nvidia-smi"

clean:
	rm -rf $(TERRAFORM_DIR)/.terraform $(TERRAFORM_DIR)/.terraform.lock.hcl
	@echo "Local Terraform cache cleared."

# ── LLM targets ──────────────────────────────────────────────────────────────
LLAMA_PORT ?= 8080

llm-tunnel:
	@echo "Opening IAP tunnel: localhost:$(LLAMA_PORT) → $(VM_NAME):$(LLAMA_PORT)"
	@echo "API will be available at http://localhost:$(LLAMA_PORT)/v1 after tunnel connects."
	gcloud compute start-iap-tunnel $(VM_NAME) $(LLAMA_PORT) \
		--local-host-port=localhost:$(LLAMA_PORT) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID)

llm-logs:
	gcloud compute ssh $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--tunnel-through-iap \
		--command="sudo journalctl -u llama-server -f --no-pager"

llm-status:
	gcloud compute ssh $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--tunnel-through-iap \
		--command="systemctl status llama-server --no-pager -l; echo '---'; ls -lh /mnt/disks/models/llm/ 2>/dev/null || echo 'LLM model dir not found yet'"

llm-test:
	@echo "Testing llama-server API on localhost:$(LLAMA_PORT)..."
	@echo "(Assumes 'make llm-tunnel' is running in another terminal)"
	./llm/api-test.sh $(LLAMA_PORT)

# ── Open WebUI targets ────────────────────────────────────────────────────────
WEBUI_PORT ?= 3000

webui-tunnel:
	@echo "Opening IAP tunnel: localhost:$(WEBUI_PORT) → $(VM_NAME):$(WEBUI_PORT)"
	@echo "Open WebUI will be available at http://localhost:$(WEBUI_PORT) after tunnel connects."
	gcloud compute start-iap-tunnel $(VM_NAME) $(WEBUI_PORT) \
		--local-host-port=localhost:$(WEBUI_PORT) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID)

webui-logs:
	gcloud compute ssh $(VM_NAME) \
		--zone=$(ZONE) \
		--project=$(PROJECT_ID) \
		--tunnel-through-iap \
		--command="sudo docker logs open-webui -f --tail 50"
