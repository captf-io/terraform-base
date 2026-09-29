# Test fixture: the no-op cluster module from cluster-api-provider-terraform
# (modules/noop/cluster), plus one real provider so the smoke test exercises
# the provider mirror with the network off.
terraform {
  required_version = ">= 1.5"

  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

resource "random_id" "mirror_check" {
  byte_length = 4
}
