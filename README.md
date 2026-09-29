# terraform-base

Base image for [CAPTF](https://github.com/captf-io) module images that run
on Terraform. It lays out the fixed paths of the `v1alpha1` image contract
so a module image only adds its module:

| Path / setting | Provided by the base |
| --- | --- |
| `/captf/runtime` | Symlink to `/usr/local/bin/terraform` (statically linked, from `hashicorp/terraform`) |
| `USER` | `65532:65532` (`captf`), for the Pod Security `restricted` profile |
| `io.captf.contract`, `io.captf.runtime`, `io.captf.runtime.version` | Labels, inherited by module images |
| OS | Ubuntu 26.04 LTS with `ca-certificates`, `git`, `openssh-client` and a shell (for `local-exec`) |
| `/captf/module`, `/captf/providers`, `io.captf.role` | **Not** provided: the module image adds these |
| `/captf/work`, `/captf/bin`, `/captf/config`, `/var/run/captf/credentials` | Left absent; the Job mounts them |

Images: `ghcr.io/captf-io/terraform-base`, multi-arch (`linux/amd64`,
`linux/arm64`).

| Tag | Meaning |
| --- | --- |
| `1.16.4` | Newest build for that Terraform release (rebuilt weekly for OS updates) |
| `1.16` | Newest build of the newest patch release of that minor |
| `1.16.4-YYYYMMDD` | That day's build; does not move |
| `latest` | Newest build |

Pin a module image's base by digest for reproducible builds.

## Building a module image

Copy [`examples/Dockerfile.module`](examples/Dockerfile.module) into your
module's root as `Dockerfile` and build it:

```sh
podman build --build-arg ROLE=cluster \
  --build-arg IMAGE_SOURCE=https://github.com/<org>/<repo> \
  --build-arg IMAGE_REVISION="$(git rev-parse HEAD)" \
  --build-arg IMAGE_VERSION=<tag> -t <registry>/<repo>:<tag> .
tfcapi-lint image <registry>/<repo>:<tag> --role cluster --strict
```

It is a two-stage build: a `mirror` stage on the same base runs `terraform
get` and `terraform providers mirror` for `linux_amd64` and `linux_arm64`
into `/captf/providers`, and the final stage copies that mirror and the
module into the base, owned by `65532`, and sets `io.captf.role` and the OCI
labels. Drop the `mirror` stage for an image that downloads providers at
`init` instead (needs registry egress at run time).

## Developing

```sh
make build        # base image for the host platform
make test         # build, then smoke-test a module image FROM it
make test TFCAPI_LINT=/path/to/tfcapi-lint   # also lint the module image
```

`make test` builds [`test/module`](test/module) (the provider's no-op cluster
module plus the `random` provider) with `examples/Dockerfile.module`, checks
its user and labels, then runs `init`, `validate`, `apply` and `destroy` the
way the CAPTF runner does: read-only root filesystem, no network, providers
from the mirror only, and `/captf/work` on a tmpfs.

The Terraform version is the tag of the `AS runtime` stage in the
[`Dockerfile`](Dockerfile); `make runtime-version` prints it and the build
fails if the binary disagrees. Dependabot bumps that line, the Ubuntu digest
(LTS only) and the pinned actions.

## CI

[`.github/workflows/build.yml`](.github/workflows/build.yml): every pull
request and push runs `make test` natively on amd64 and arm64 runners; a
push to `main`, the weekly schedule and a manual dispatch also build the
multi-arch image with QEMU and push it to GHCR with SBOM and provenance
attestations.

## x86-64 baseline

Ubuntu 26.04 targets the baseline x86-64 ISA, so the image runs on any
amd64 node. (RHEL 10 derivatives such as Rocky Linux 10 require x86-64-v3,
which older nodes lack.)

## License

[Apache 2.0](LICENSE.md)
