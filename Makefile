RUNTIME := terraform
IMAGE ?= ghcr.io/captf-io/terraform-base
ENGINE ?= podman
# tfcapi-lint binary for `make test`; empty skips the image lint.
TFCAPI_LINT ?=

# The runtime version is the tag of the Dockerfile's `AS runtime` stage,
# so a Dependabot bump of that FROM line is the only edit a new version
# needs.
RUNTIME_VERSION := $(shell sed -n 's|^FROM [^ ]*:\([^@ ]*\)@[^ ]* AS runtime$$|\1|p' Dockerfile | sed 's/-minimal$$//')
TAG ?= $(RUNTIME_VERSION)

.PHONY: help runtime-version build test

help: ## Show targets.
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "%-16s %s\n", $$1, $$2}'

runtime-version: ## Print the runtime version the Dockerfile pins.
	@echo $(RUNTIME_VERSION)

build: ## Build the base image for the host platform as $(IMAGE):$(TAG).
	$(ENGINE) build -f Dockerfile --build-arg RUNTIME_VERSION=$(RUNTIME_VERSION) -t $(IMAGE):$(TAG) .

test: build ## Build, then smoke-test a module image built FROM the base.
	ENGINE=$(ENGINE) RUNTIME=$(RUNTIME) TFCAPI_LINT=$(TFCAPI_LINT) ./test/smoke.sh $(IMAGE):$(TAG) $(RUNTIME_VERSION)
