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

# Contract outputs of the cluster role, v1alpha1.

# A user or control-plane endpoint wins; otherwise a stable, valid endpoint
# derived from the object name (.invalid never resolves, RFC 2606).
output "control_plane_endpoint" {
  value = var.control_plane_endpoint != null ? var.control_plane_endpoint : {
    host = "noop-${var.captf_object.name}.invalid"
    port = 6443
  }
}

output "failure_domains" {
  value = [{ name = "fd1", control_plane = true }]
}

output "exports" {
  value = { backend_id = "noop-backend-${terraform_data.load_balancer.id}" }
}

output "health" {
  value = { state = "running", healthy = true, message = null, reasons = [] }
}
