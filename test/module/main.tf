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

# No-op cluster module: implements the v1alpha1 cluster role with no cloud.
# Every "resource" is a terraform_data holding the inputs it was given, so
# plans, state and outputs are real while nothing is provisioned.

# The stand-in for a load balancer and network: exports carry its id, so
# machines receive a value that only exists after this module applied.
resource "terraform_data" "load_balancer" {
  input = {
    cluster                   = var.captf_cluster
    object                    = var.captf_object
    tags                      = var.captf_tags
    control_plane_endpoint    = var.control_plane_endpoint
    kubernetes_version        = var.kubernetes_version
    control_plane_initialized = var.control_plane_initialized
    cluster_network           = var.cluster_network
  }
}
