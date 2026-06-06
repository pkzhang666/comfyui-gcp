# Backend configured via backend.tfvars (gitignored — values stay local only)
# Copy terraform/backend.tfvars.example → terraform/backend.tfvars and fill in your values
# Then run: terraform init -backend-config=backend.tfvars
terraform {
  backend "gcs" {}
}
