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

# captf Terraform base image: Ubuntu LTS with the Terraform binary at the
# fixed paths of the CAPTF v1alpha1 image contract. A module image builds
# FROM this and adds only /captf/module (and, optionally, /captf/providers);
# see examples/Dockerfile.module.
#
# Build with `make build`, which derives RUNTIME_VERSION from the runtime
# FROM tag below; the build fails if the two disagree.
#
# Every FROM is pinned by the digest of its multi-arch index, so a moved tag
# cannot change what is built; the tag stays for readers and Dependabot.
# To bump by hand:
#   skopeo inspect --format '{{.Digest}}' docker://<image>:<tag>

# hashicorp/terraform is Alpine, but the binary is statically linked, so it
# runs unchanged on Ubuntu.
FROM docker.io/hashicorp/terraform:1.16.5@sha256:c7926feace05d0f7e73542842bf3945924e955a1f782cf000ccbb8d18fa42d77 AS runtime

FROM docker.io/library/ubuntu:26.04@sha256:da6fc2be547864451aa253836dd926da33623312df4a9a243e35dc877c378a78
ARG RUNTIME_VERSION
ARG IMAGE_SOURCE=""
ARG IMAGE_REVISION=""
ARG IMAGE_VERSION=""

# Upgrade first: the pinned Ubuntu digest moves only on a Dependabot bump,
# and the weekly CI rebuild uses this to pick up security fixes in between.
#
# git and ssh for modules and providers that fetch over git; a shell comes
# with the base, for local-exec provisioners. The reserved paths
# (/captf/work, /captf/bin, /captf/config, /var/run/captf/credentials) are
# left absent for the Job to mount.
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends ca-certificates git openssh-client \
 && rm -rf /var/lib/apt/lists/* \
 && groupadd --gid 65532 captf \
 && useradd --uid 65532 --gid 65532 --no-create-home --home-dir /tmp \
      --shell /usr/sbin/nologin captf \
 && install -d -m 0755 /captf

COPY --from=runtime /bin/terraform /usr/local/bin/terraform
RUN test -n "${RUNTIME_VERSION}" \
 && test "$(terraform version | head -n1)" = "Terraform v${RUNTIME_VERSION}" \
 && ln -s /usr/local/bin/terraform /captf/runtime

USER 65532:65532
WORKDIR /captf
# The runner replaces the entrypoint; this one is for `podman run` by hand.
ENTRYPOINT ["/captf/runtime"]
# Every label is inherited by module images: the io.captf.* ones are
# correct there as is, and a module image overrides the OCI ones (and adds
# io.captf.role).
LABEL io.captf.contract="v1alpha1" \
      io.captf.runtime="terraform" \
      io.captf.runtime.version="${RUNTIME_VERSION}" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.version="${IMAGE_VERSION}"
