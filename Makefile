TERRAFORM_DIR := terraform

# Load .env if present (copy .env.example → .env and fill in your values)
-include .env
export

.PHONY: help check init plan apply destroy start stop ssh tunnel status logs gpu-status clean genconfig

help:
	@echo ""
	@echo "ComfyUI Workflow — Infrastructure Management"
	@echo "============================================="
	@echo ""
	@echo "  check      Check prerequisites (gcloud, terraform)"
	@echo "  genconfig  Generate terraform/*.tfvars from .env + templates"
	@echo "  init       Initialize Terraform backend"
	@echo "  plan       Preview infrastructure changes"
	@echo "  apply      Deploy/update infrastructure"
	@echo "  destroy    Tear down all infrastructure"
	@echo ""
	@echo "  start    Start the ComfyUI VM (billing resumes)"
	@echo "  stop     Stop the VM to save costs"
	@echo "  ssh      Open SSH session via IAP tunnel"
	@echo "  tunnel   Forward port 8188 → localhost:8188 via IAP"
	@echo "  status   Show VM state and ComfyUI service status"
	@echo "  logs     Stream ComfyUI service logs"
	@echo "  gpu      Show GPU utilization (nvidia-smi)"
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
