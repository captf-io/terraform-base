# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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

# The Apache-2.0 license header check: .licenserc.yaml says which files need
# the header. Runs as the host user, so fix-headers keeps file ownership.
LICENSE_EYE_IMAGE := docker.io/apache/skywalking-eyes:0.9.0@sha256:cd89ccbbcba2e87d3fb0e34b156b1da208d6c5ac1ada4e2d335e920022c765b8
ifeq ($(ENGINE),docker)
LICENSE_EYE_USER := --user $(shell id -u):$(shell id -g)
else
LICENSE_EYE_USER := --userns=keep-id --user $(shell id -u):$(shell id -g)
endif
LICENSE_EYE = $(ENGINE) run --rm $(LICENSE_EYE_USER) --security-opt label=disable \
	-v "$(CURDIR):/work" -w /work "$(LICENSE_EYE_IMAGE)"

.PHONY: check-headers fix-headers

check-headers: ## Fail on any source file without the Apache-2.0 license header (.licenserc.yaml).
	@$(LICENSE_EYE) header check

fix-headers: ## Add the Apache-2.0 license header to every source file missing it.
	@$(LICENSE_EYE) header fix
