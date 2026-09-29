#!/usr/bin/env bash
# Smoke test for a base image: build a module image FROM it with
# examples/Dockerfile.module, check its config against the image
# contract, then run init/validate/apply/destroy the way the CAPTF runner
# does: read-only root, network off, providers from the mirror only, and the
# working directory on a tmpfs at /captf/work (exec, like the emptyDir the
# Job mounts; docker's --tmpfs defaults to noexec).
#
# Usage: test/smoke.sh <base-image> <runtime-version>
# Env:   ENGINE (podman|docker, default podman), RUNTIME (terraform|tofu),
#        TFCAPI_LINT (path to tfcapi-lint; run `image --strict` when set).
set -euo pipefail

base=${1:?usage: smoke.sh <base-image> <runtime-version>}
version=${2:?usage: smoke.sh <base-image> <runtime-version>}
engine=${ENGINE:-podman}
runtime=${RUNTIME:?RUNTIME must be terraform or tofu}
here=$(cd "$(dirname "$0")" && pwd)
repo=$(dirname "$here")
module_image="localhost/captf-smoke-${runtime}:${version}"

fail() { echo "FAIL: $*" >&2; exit 1; }
label() { "$engine" image inspect --format "{{index .Config.Labels \"$1\"}}" "$module_image"; }

echo "--- build module image from $base"
"$engine" build -f "$repo/examples/Dockerfile.module" \
  --build-arg BASE="$base" --build-arg ROLE=cluster \
  --build-arg IMAGE_VERSION=smoke -t "$module_image" "$here/module"

echo "--- image config"
user=$("$engine" image inspect --format '{{.Config.User}}' "$module_image")
[[ $user == 65532:65532 ]] || fail "user is '$user', want 65532:65532"
[[ $(label io.captf.contract) == v1alpha1 ]] || fail "io.captf.contract"
[[ $(label io.captf.role) == cluster ]] || fail "io.captf.role"
[[ $(label io.captf.runtime) == "$runtime" ]] || fail "io.captf.runtime"
[[ $(label io.captf.runtime.version) == "$version" ]] || fail "io.captf.runtime.version"
[[ $(label org.opencontainers.image.version) == smoke ]] || fail "org.opencontainers.image.version"

echo "--- layout and runner-style run (read-only, no network)"
"$engine" run --rm --network=none --read-only \
  --tmpfs /captf/work:rw,exec,mode=1777 --tmpfs /tmp:rw,exec,mode=1777 \
  -v "$here/root:/captf/config:ro,Z" \
  -e HOME=/captf/work -e TF_DATA_DIR=/captf/work/.terraform \
  -e TF_CLI_CONFIG_FILE=/captf/work/cli.tfrc -e TF_IN_AUTOMATION=1 -e TF_INPUT=0 \
  --entrypoint /bin/sh "$module_image" -euc '
    for p in /captf/bin /var/run/captf/credentials; do
      [ ! -e "$p" ] || { echo "FAIL: reserved path $p exists" >&2; exit 1; }
    done
    [ -x /captf/runtime ] || { echo "FAIL: /captf/runtime not executable" >&2; exit 1; }
    ls /captf/module/*.tf >/dev/null
    [ -d /captf/providers/registry.terraform.io ] || [ -d /captf/providers/registry.opentofu.org ] \
      || { echo "FAIL: provider mirror empty" >&2; exit 1; }
    git --version >/dev/null && ssh -V 2>/dev/null
    cat > /captf/work/cli.tfrc <<EOF
provider_installation {
  filesystem_mirror {
    path    = "/captf/providers"
    include = ["*/*/*"]
  }
  direct {
    exclude = ["*/*/*"]
  }
}
EOF
    mkdir /captf/work/root && cp /captf/config/main.tf.json /captf/work/root/
    cd /captf/work/root
    r=/captf/runtime
    $r version
    $r init -input=false -no-color
    $r validate -json -no-color >/tmp/validate.json || { cat /tmp/validate.json; exit 1; }
    $r apply -auto-approve -input=false -no-color
    $r destroy -auto-approve -input=false -no-color
  '

if [[ -n ${TFCAPI_LINT:-} ]]; then
  echo "--- tfcapi-lint image"
  archive=$(mktemp -d)
  trap 'rm -rf -- "$archive"' EXIT
  "$engine" save --format oci-dir -o "$archive/img" "$module_image"
  "$TFCAPI_LINT" image --role cluster --strict "oci:$archive/img"
fi

echo "PASS: $base"
